/**
* @author Unit Test Generation Bot
* @description Test Class for PGVisitMgmt
*/

@isTest
private class PGVisitMgmtTest {
	@testSetup static void prepareData() {
		//Data preparation
		 
	}
	

	
	
	static testMethod void testGenerateVisits() {
		//Data Setup
		List<SObject> sobjList = TestUtil.getSObjectList(new Account().getSObjectType());
		List<Account> accounts = (List<Account>)sobjList;
		//Start the testing
		Test.startTest();
		PGVisitMgmt pGVisitMgmt_Obj = new PGVisitMgmt();
		List<Visit__c> returnList = pGVisitMgmt_Obj.generateVisits(accounts);
		Test.stopTest();
		//Assertion starts here
		System.assert(returnList.size()>0);
	}
	

	
	
	static testMethod void testGenerateVisits43ac78fe() {
		//Data Setup
		List<SObject> sobjList = TestUtil.getSObjectList(new Account().getSObjectType());
		List<Account> accounts = (List<Account>)sobjList;
		Date fromDate = Date.newInstance(2019, 3, 11);
		//Start the testing
		Test.startTest();
		PGVisitMgmt pGVisitMgmt_Obj = new PGVisitMgmt();
		List<Visit__c> returnList = pGVisitMgmt_Obj.generateVisits(accounts, fromDate);
		Test.stopTest();
		//Assertion starts here
		System.assert(returnList.size()>0);
	}
	

	
	
	static testMethod void testUpdateSeqAsync() {
		//Data Setup
		Map<Id,Route_to_User__c> route_to_Userc_ObjMap = new Map<Id,Route_to_User__c>([SELECT id FROM Route_to_User__c]);
		List<Id> vIds = new List<Id>();
		Set<Id> tempSet1 = route_to_Userc_ObjMap.keyset();
		for(Id str:tempSet1){
			vIds.add(str);
		}
		//Start the testing
		Test.startTest();
		PGVisitMgmt.updateSeqAsync(vIds);
		Test.stopTest();
		//Assertion starts here
		
	}
	

	
	
	static testMethod void testUpdateSeq() {
		//Data Setup
		Map<Id,Route_to_User__c> route_to_Userc_ObjMap = new Map<Id,Route_to_User__c>([SELECT id FROM Route_to_User__c]);
		List<Id> vIds = new List<Id>();
		Set<Id> tempSet1 = route_to_Userc_ObjMap.keyset();
		for(Id str:tempSet1){
			vIds.add(str);
		}
		//Start the testing
		Test.startTest();
		PGVisitMgmt.updateSeq(vIds);
		Test.stopTest();
		//Assertion starts here
		
	}
	

	
	
	static testMethod void testInsertVisits() {
		//Data Setup
		List<SObject> sobjList = TestUtil.getSObjectList(new Visit__c().getSObjectType());
		List<Visit__c> newVisits = (List<Visit__c>)sobjList;
		//Start the testing
		Test.startTest();
		PGVisitWrapper returnObj = PGVisitMgmt.insertVisits(newVisits);
		Test.stopTest();
		//Assertion starts here
		System.assert(returnObj!=null);
	}
	

	
	
	static testMethod void testUpdateVisits() {
		//Data Setup
		Map<Visit__c,Visit__c> updateMap = new Map<Visit__c,Visit__c>();
		//Start the testing
		Test.startTest();
		PGVisitWrapper returnObj = PGVisitMgmt.updateVisits(updateMap);
		Test.stopTest();
		//Assertion starts here
		System.assert(returnObj!=null);
	}
	

}