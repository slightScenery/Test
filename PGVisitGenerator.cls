/***
 * PGVisitGenerator - Visit generator for accounts on one route for current week
 *
 * @author Wenbo Zhou
 * @date 8/7/2018
 */
public without sharing class PGVisitGenerator {
    private Map<Id, Route_to_Account__c> accIdToRouteToAccountMap;
    private Map<Id, Account> accIdToAccountMap = new Map<Id, Account>();

    @TestVisible
    private Date weekStartDate;
    @TestVisible
    private Map<Integer, List<Visit__c>> weeklyVisits = new Map<Integer, List<Visit__c>>();

    public PGVisitGenerator(List<Route_to_Account__c> routeToAccounts, List<Account> accounts) {
        this(routeToAccounts, accounts, System.now().date());
    }

    public PGVisitGenerator(List<Route_to_Account__c> routeToAccounts, List<Account> accounts,
            Date referenceDate) {
        this.weekStartDate = referenceDate;
        accIdToRouteToAccountMap = new Map<Id, Route_to_Account__c>();
        Set<Id> availableAccountIds = new Set<Id>();
        for (Route_to_Account__c routeToAcc : routeToAccounts) {
            availableAccountIds.add(routeToAcc.Account__c);
            accIdToRouteToAccountMap.put(routeToAcc.Account__c, routeToAcc);
        }

        // if an account is not in the route, it will be ignored for further processing
        accIdToAccountMap = new Map<Id, Account>();
        for (Account acc : accounts) {
            if (availableAccountIds.contains(acc.Id)) {
                accIdToAccountMap.put(acc.Id, acc);
            }
        }

        // create weekday to visit list mapping, 0 - Monday, 6 - Sunday
        for (Integer i : PGConstants.WORK_DAYS) {
            weeklyVisits.put(i, new List<Visit__c>());
        }
    }

    public Date getStartDate() {
        return weekStartDate;
    }

    public Map<Integer, List<Visit__c>> getWeeklyVisits() {
        return weeklyVisits;
    }

    public PGVisitGenerator generate() {
        System.debug('***** Visit generation started');
        for (Account account : accIdToAccountMap.values()) {
            String weekdayStr = account.Weekday_Schedule__c;
            Integer visitFrequency = account.Weekly_Visit_Frequency__c.intValue();

            String[] preferredWeekdays = new String[]{
            };
            if (!String.isBlank(weekdayStr)) {
                preferredWeekdays = weekdayStr.split(';');
            }

            // VISIT GENERATION RULES
            // if the number of preferred weekday matches the visit frequency, schedule accordingly
            if (preferredWeekdays.size() == visitFrequency) {
                for (String weekday : preferredWeekdays) {
                    Integer weekdayNo = PGConstants.WEEKDAY_TO_NO.get(weekday);
                    Date visitDate = weekStartDate.addDays(weekdayNo);
                    createVisitForWeekday(account, weekdayNo, visitDate);
                }
            } else {
                // else schedule with the amount of visits from monday
                for (Integer weekdayNo = 0; weekdayNo < visitFrequency; weekdayNo++) {
                    Date visitDate = weekStartDate.addDays(weekdayNo);
                    createVisitForWeekday(account, weekdayNo, visitDate);
                }
            }
        }
        System.debug('***** Visit generation ended');
        return this;
    }

    private void createVisitForWeekday(Account account, Integer weekdayNo, Date visitDate) {
        Visit__c v = new Visit__c();
        v.Store__c = account.Id;
        v.Route_to_Account__c = accIdToRouteToAccountMap.get(account.Id).Id;
        v.Schedule_Date__c = visitDate;
        v.Status__c = 'Open';
        String isAutoGen = Application_Configuration__c.getAll().get('Order_Locale_Autogen').Value__c;
        if (String.isNotEmpty(isAutoGen) && isAutoGen.toLowerCase()=='y'){
            v.Is_Generated__c = TRUE;
        }
        weeklyVisits.get(weekdayNo).add(v);
    }
}