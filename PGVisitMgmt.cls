/**************************************************************************************************
 * Name: PGVisitMgmt
 * Purpose: visit management util class
 * Author: Kevin Mao
 * Create Date: 2018-07-19
 **************************************************************************************************/

public without sharing class PGVisitMgmt {

    public List<Visit__c> generateVisits(List<Account> accounts) {
        return generateVisits(accounts, null);
    }

    public List<Visit__c> generateVisits(List<Account> accounts, Date fromDate) {
        Map<Id, Account> accIdToAccMap = new Map<Id, Account>();
        for (Account account : accounts) {
            accIdToAccMap.put(account.Id, account);
        }

        List<Route_to_Account__c> routeToAccounts = [
                SELECT Id, Route__c, Account__c
                FROM Route_to_Account__c
                WHERE Is_Active__c = TRUE
                AND Account__c IN :accIdToAccMap.keySet()
        ];
        Map<Id, List<Route_to_Account__c>> routeIdToRouteAccMap = new Map<Id, List<Route_to_Account__c>>();
        for (Route_to_Account__c routeAcc : routeToAccounts) {
            if (routeIdToRouteAccMap.containsKey(routeAcc.Route__c)) {
                routeIdToRouteAccMap.get(routeAcc.Route__c).add(routeAcc);
            } else {
                routeIdToRouteAccMap.put(routeAcc.Route__c, new List<Route_to_Account__c>{
                        routeAcc
                });
            }
        }

        List<Route_to_User__c> routeToUsers = [
                SELECT Id, Route__c, User__c
                FROM Route_to_User__c
                WHERE Is_Active__c = TRUE
                AND Route__c IN :routeIdToRouteAccMap.keySet()
        ];
        Map<Id, List<Id>> routeIdToUserIdMap = new Map<Id, List<Id>>();
        for (Route_to_User__c routeUser : routeToUsers) {
            if (routeIdToUserIdMap.containsKey(routeUser.Route__c)) {
                routeIdToUserIdMap.get(routeUser.Route__c).add(routeUser.User__c);
            } else {
                routeIdToUserIdMap.put(routeUser.Route__c, new List<Id> {routeUser.User__c});
            }
        }

        // get weekstartdate
        Date weekStartDate = System.now().date().toStartOfWeek();
        if (fromDate != null) {
            weekStartDate = fromDate.toStartOfWeek();
        }
        if (Math.mod(Date.newInstance(1900, 1, 7).daysBetween(weekStartDate), 7) == 0) {
            // Start of the week is on a Sunday, add 1 to shift to Monday
            weekStartDate = weekStartDate.addDays(1);
        }

        // prepare available user mangement object
        PGAvailableUserMgmt aum = new PGAvailableUserMgmt(accIdToAccMap, routeIdToUserIdMap, weekStartDate);

        // generate and schedule visits
        List<Visit__c> newVisits = new List<Visit__c>();
        for (Id routeId : routeIdToRouteAccMap.keySet()) {

            PGVisitGenerator generator = new PGVisitGenerator(
                    routeIdToRouteAccMap.get(routeId),
                    accounts,
                    weekStartDate
            );
            generator.generate();
            PGVisitScheduler scheduler = new PGVisitScheduler(
                    generator.getWeeklyVisits(),
                    accounts,
                    aum.getUserWeekdayHours(routeId),
                    weekStartDate
            );
            scheduler.schedule();
            newVisits.addAll(scheduler.getAllVisits(true));
        }
        return newVisits;
    }

    // when we create new visits, we need to update the visits seq in one day run by one user
    // so we need to get exists visits and combine to new visits and then update seq for all visits
    // one date and one user determine one visit list
    //

    @Future(Callout=true)
    public static void updateSeqAsync(List<Id> vIds) {
        updateSeq(vIds);
    }

    public static void updateSeq(List<Id> vIds) {
        List<Visit__c> allVisits = [
                SELECT Id, Route_to_Account__c, Schedule_Date__c, Assigned_To__c, Visit_Latitude__c, Visit_Longitude__c
                FROM Visit__c
                WHERE Id IN :vIds
                AND Route_to_Account__c != NULL
                AND Status__c != 'Cancelled'
        ];
        //firstly we need to get all routes' warehouse location.
        Map<Id, List<Double>> rlmap = new Map<Id, List<Double>>();
        List<Id> route2Acct = new List<Id>();
        for (Visit__c v : allVisits) {
            route2Acct.add(v.Route_to_Account__c);
        }
        Map<Id, Route_to_Account__c> route2AcctMap = new Map<Id, Route_to_Account__c>([SELECT Id, Route__c FROM Route_to_Account__c WHERE Id IN :route2Acct]);
        ////firstly we need to get the warehouse location
        List<Route_to_Location__c> route2location = [SELECT Route__c,Location__r.Coordinate__Latitude__s,Location__r.Coordinate__Longitude__s FROM Route_to_Location__c];
        for (Route_to_Location__c rlobjt : route2location) {
            List<Double> coord = new List<Double>();
            coord.add(rlobjt.Location__r.Coordinate__Latitude__s);
            coord.add(rlobjt.Location__r.Coordinate__Longitude__s);
            rlmap.put(rlobjt.Route__c, coord);
        }
        System.debug(rlmap.keySet());

        Map<VisitPair, List<Visit__c>> visitRoutes = new Map<VisitPair, List<Visit__c>>();
        Map<VisitPair, Id> visitRouteIds = new Map<VisitPair, Id>();
        Set<Id> routeIds = new Set<Id>();
        for (Visit__c visit : allVisits) {
            VisitPair pair = new VisitPair(visit.Schedule_Date__c, visit.Assigned_To__c);
            List<Visit__c> visitrs = new List<Visit__c>();
            if (visitRoutes.containsKey(pair)) {
                visitrs = visitRoutes.get(pair);
            }
            visitrs.add(visit);
            visitRoutes.put(pair, visitrs);
            Id routeId = route2AcctMap.get(visit.Route_to_Account__c).Route__c;
            routeIds.add(routeId);
            visitRouteIds.put(pair, routeId);
        }
        System.debug('*** routeIds: ' + routeIds);
        SSC_GMAP_DirectionServiceRequest req = new SSC_GMAP_DirectionServiceRequest();
        String key = Application_Configuration__c.getAll().get('GMAP_API_KEY').Value__c;
        SSC_GMAP_Service dService = new SSC_GMAP_DirectionService(key);
        for (VisitPair vpair : visitRoutes.keySet()) {
            List<SSC_GMAP_DirectionServiceRequest.Waypoint> waypoints
                    = new List<SSC_GMAP_DirectionServiceRequest.Waypoint>();
            List<Visit__c> curvisits = visitRoutes.get(vpair);
            Id rId = visitRouteIds.get(vpair);
            List<Double> coordpair = rlmap.get(rId);
            if (coordpair.isEmpty() || coordpair.size() < 2) continue;
            for (Visit__c visit : curvisits) {
                Double lat = visit.Visit_Latitude__c;
                Double lon = visit.Visit_Longitude__c;
                SSC_GMAP_DirectionServiceRequest.Waypoint wayPoint =
                        new SSC_GMAP_DirectionServiceRequest.Waypoint(lat, lon);
                System.debug('*** wayPoint: ' + wayPoint);
                waypoints.add(wayPoint);
            }
            String point = coordpair.get(0) + ',' + coordpair.get(1);
            req.origin(point)
                    .destination(point)
                    .mode(SSC_GMAP_DirectionServiceRequest.TravelMode.DRIVING)
                    .optimizeWaypoints(true)
                    .waypoints(waypoints);
            SSC_GMAP_DirectionServiceResponse resp = (SSC_GMAP_DirectionServiceResponse) dService.call(req);
            System.debug('*** resp: ' + resp.body);
            if (resp.routes == null || resp.routes.size() == 0) {
                throw new PGException('GMap service responded with no routes. Please check for account address');
            }
            Integer[] orderResult = resp.routes[0].waypoint_order;
            Integer idx = 0;
            for (Visit__c visit : curvisits) {
                visit.Sequence__c = orderResult[idx];
                System.debug(visit.Sequence__c);
                idx++;
            }

        }
        update allVisits;
    }

    /**************************************
     * Purpose: process visits insert logic
     * Author: Kevin Mao
     * Modified Date: 2018-07-27
    ***************************************/
    public static PGVisitWrapper insertVisits(List<Visit__c> newVisits) {
        List<Id> userIds = new List<Id>();
        List<Date> visitDates = new List<Date>();
        List<Id> accIds = new List<Id>();
        List<Visit_List__c> newvisitlists = new List<Visit_List__c>();
        for (Visit__c v : newVisits) {
            if (v.Status__c == 'Cancelled') continue;
            userIds.add(v.Assigned_To__c);
            visitDates.add(v.Schedule_Date__c);
            accIds.add(v.Store__c);
        }
        Map<Id, Account> accMap = new Map<Id, Account>([SELECT Id, Visit_Duration__c FROM Account WHERE Id IN :accIds]);
        //need to get some relation fields in Visit
        List<Visit_List__c> lists = [SELECT Id,Schedule_Date__c,Visit_Duration__c,OwnerId FROM Visit_List__c WHERE Schedule_Date__c IN :visitDates AND OwnerId IN :userIds AND Status__c = 'Active'];
        Map<VisitPair, Visit_List__c> vMap = new Map<VisitPair, Visit_List__c>();
        Map<VisitPair, Visit_List__c> nvMap = new Map<VisitPair, Visit_List__c>();
        Map<Visit__c, Visit_List__c> connectedMap = new Map<Visit__c, Visit_List__c>();
        for (Visit_List__c l : lists) {
            VisitPair pair = new VisitPair(l.Schedule_Date__c, l.OwnerId);
            vMap.put(pair, l);
        }
        for (Visit__c visit : newVisits) {
            VisitPair pair = new VisitPair(visit.Schedule_Date__c, visit.Assigned_To__c);
            Integer cDuration = Integer.valueOf(accMap.get(visit.Store__c).Visit_Duration__c);
            if (vMap.containsKey(pair)) {
                Visit_List__c tmp = vMap.get(pair);
                visit.Visit_List__c = tmp.Id;
                tmp.Visit_Duration__c = tmp.Visit_Duration__c + cDuration;
                vMap.put(pair, tmp);
            } else {
                Visit_List__c newlist = new Visit_List__c();

                if (nvMap.containsKey(pair)) {
                    newlist = nvMap.get(pair);
                    newlist.Visit_Duration__c = newlist.Visit_Duration__c + cDuration;
                } else {
                    newlist.Schedule_Date__c = visit.Schedule_Date__c;
                    newlist.OwnerId = visit.Assigned_To__c;
                    newlist.Visit_Duration__c = cDuration;
                    newvisitlists.add(newlist);
                    nvMap.put(pair, newlist);
                }
                connectedMap.put(visit, newlist);
            }
        }
        System.debug('connectedMap size' + connectedMap.size());
        System.debug('list size ' + newvisitlists.size());
        System.debug('visit size ' + newVisits.size());
        PGVisitWrapper resultWrapper = new PGVisitWrapper(newVisits, newvisitlists, connectedMap);
        return resultWrapper;
    }


    /**************************************
     * Purpose: process visits update logic
     * Author: Kevin Mao
     * Modified Date: 2018-07-26
    ***************************************/
    public static PGVisitWrapper updateVisits(Map<Visit__c, Visit__c> updateMap) {
        //Get all udpate visits' account's visit date list
        List<Id> accountIds = new List<Id>();
        List<Id> userIds = new List<Id>();
        List<Id> listIds = new List<Id>();
        List<Id> newuserIds = new List<Id>();
        Map<Visit__c, Visit_List__c> connectedMap = new Map<Visit__c, Visit_List__c>();
        List<Visit__c> visitResult = new List<Visit__c>();
        List<Visit_List__c> listResult = new List<Visit_List__c>();
        for (Visit__c visit : updateMap.keySet()) {
            accountIds.add(visit.Store__c);
            userIds.add(visit.Assigned_To__c);
            if (!listIds.contains(visit.Visit_List__c)) {
                listIds.add(visit.Visit_List__c);
            }
            if (visit.Assigned_To__c != updateMap.get(visit).Assigned_To__c) {
                newuserIds.add(updateMap.get(visit).Assigned_To__c);
            }
        }
        List<Visit__c> visitDts = [SELECT Store__c,Schedule_Date__c FROM Visit__c WHERE Store__c IN :accountIds AND Status__c != 'Cancelled'];
        Map<Id, List<Date>> accDateMap = new Map<Id, List<Date>>();
        Map<Id, Account> durationMap = new Map<Id, Account>([SELECT Id, Visit_Duration__c FROM Account WHERE Id IN :accountIds]);
        for (Visit__c visit : visitDts) {
            List<Date> tmpDts = new List<Date>();
            if (accDateMap.containsKey(visit.Store__c)) {
                tmpDts = accDateMap.get(visit.Store__c);
            }
            tmpDts.add(visit.Schedule_Date__c);
            accDateMap.put(visit.Store__c, tmpDts);
        }
        //Get max seq of all the user by all the date
        Map<VisitPair, Decimal> maxseqMap = new Map<VisitPair, Decimal>();
        List<Visit__c> visitSeqs = [SELECT Sequence__c,Schedule_Date__c,Assigned_To__c FROM Visit__c WHERE Assigned_To__c IN :userIds AND Status__c != 'Cancelled'];
        for (Visit__c visit : visitSeqs) {
            VisitPair pair = new VisitPair(visit.Schedule_Date__c, visit.Assigned_To__c);
            if (maxseqMap.containsKey(pair)) {
                if (maxseqMap.get(pair) < visit.Sequence__c) {
                    maxseqMap.put(pair, visit.Sequence__c);
                }
            } else {
                maxseqMap.put(pair, visit.Sequence__c);
            }
        }
        //
        Map<VisitPair, Visit_List__c> visitlistMap = new Map<VisitPair, Visit_List__c>();
        Map<VisitPair, Visit_List__c> alreadyCreated = new Map<VisitPair, Visit_List__c>();
        List<Visit_List__c> ovisitlists = [SELECT Id,Schedule_Date__c,OwnerId,Visit_Duration__c FROM Visit_List__c WHERE Id IN :listIds AND Status__c = 'Active'];
        for (Visit_List__c lst : ovisitlists) {
            VisitPair pair = new VisitPair(lst.Schedule_Date__c, lst.OwnerId);
            visitlistMap.put(pair, lst);
        }
        List<Visit_List__c> nvisitlists = [SELECT Id,Schedule_Date__c,OwnerId,Visit_Duration__c FROM Visit_List__c WHERE OwnerId IN :newuserIds AND Status__c = 'Active'];
        for (Visit_List__c lst : nvisitlists) {
            VisitPair pair = new VisitPair(lst.Schedule_Date__c, lst.OwnerId);
            visitlistMap.put(pair, lst);
        }

        for (Visit__c oV : updateMap.keySet()) {
            System.debug('*** oV: ' + oV);
            Visit__c uV = updateMap.get(oV);
            System.debug('*** uV: ' + uV);
            // when today's visit not finished, so merge those not completed visit to next day
            if (uV.Status__c == 'Pending') {
                Date nextday = uV.Schedule_Date__c.addDays(1);
                List<Date> dates = accDateMap.get(uV.Store__c);
                VisitPair tmp = new VisitPair(nextday, uV.Assigned_To__c);
                if (dates.contains(nextday)) {
                    //if nextday has schedule for this store
                    //then we need to mark this visit to merged
                    uV.Status__c = 'Merged';
                } else {
                    //if nextday has no schedule for this store
                    //then we need to make the order of this store to the max sequence + 1
                    if (!maxseqMap.containsKey(tmp)) {
                        uV.Sequence__c = 0;
                    } else {
                        uV.Sequence__c = maxseqMap.get(tmp) + 1;
                    }
                    uV.Schedule_Date__c = nextday;
                }
            }
            if (oV.Assigned_To__c != uV.Assigned_To__c) {
                //we need to know if the new assigned user has visit list today?
                VisitPair curpair = new VisitPair(uV.Schedule_Date__c, uV.Assigned_To__c);
                VisitPair oldpair = new VisitPair(oV.Schedule_Date__c, oV.Assigned_To__c);
                //if new assigned user has visit list today
                //then we should update old user's visit list duration sub
                //update new user's visit list duration plus
                //finally update visit's visit list link to new user's visit list
                Visit_List__c ovlist = visitlistMap.get(oldpair);
                if (visitlistMap.containsKey(curpair)) {
                    System.debug('*** visitlistMap.containsKey(curpair)');
                    Visit_List__c curlist = visitlistMap.get(curpair);
                    Integer oldDuration = visitlistMap.get(oldpair) == null ? 0 : Integer.valueOf(visitlistMap.get(oldpair).Visit_Duration__c);
                    Integer updateDuration = visitlistMap.get(curpair) == null ? 0 : Integer.valueOf(visitlistMap.get(curpair).Visit_Duration__c);
                    ovlist.Visit_Duration__c = oldDuration - durationMap.get(oV.Store__c).Visit_Duration__c;
                    curlist.Visit_Duration__c = updateDuration + durationMap.get(oV.Store__c).Visit_Duration__c;
                    uV.Visit_List__c = curlist.Id;
                    uV.Sequence__c = maxseqMap.get(curpair);
                    listResult.add(ovlist);
                    listResult.add(curlist);
                }
                //otherwise we need to create a new visitlist
                else {
                    System.debug('*** !visitlistMap.containsKey(curpair)');
                    Visit_List__c newlist = new Visit_List__c();
                    if (alreadyCreated.containsKey(curpair)) {
                        newlist = alreadyCreated.get(curpair);
                        newlist.Visit_Duration__c = newlist.Visit_Duration__c + durationMap.get(uV.Store__c).Visit_Duration__c;
                    } else {
                        newlist.Visit_Duration__c = durationMap.get(uV.Store__c).Visit_Duration__c;
                        alreadyCreated.put(curpair, newlist);
                    }
                    newlist.Schedule_Date__c = uV.Schedule_Date__c;
                    newlist.OwnerId = uV.Assigned_To__c;
                    uV.Sequence__c = 0;
                    ovlist.Visit_Duration__c = ovlist.Visit_Duration__c - newlist.Visit_Duration__c;
                    listResult.add(newlist);
                    listResult.add(ovlist);
                    connectedMap.put(uV, newlist);
                }

            }
            visitResult.add(uV);
        }

        PGVisitWrapper wrapper = new PGVisitWrapper(visitResult, listResult, connectedMap);
        return wrapper;
    }

    public void test(){
        
    }
}