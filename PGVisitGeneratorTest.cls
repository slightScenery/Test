/**
* @author Unit Test Generation Bot
* @description Test Class for PGVisitGenerator
*/

@isTest
private class PGVisitGeneratorTest {
	@testSetup static void prepareData() {
		//Data preparation
		 
	}
	

	
	
	static testMethod void testGetStartDate() {
		//Data Setup
		
		//Start the testing
		Test.startTest();
		PGVisitGenerator pGVisitGenerator_Obj = new PGVisitGenerator();
		Date returnVal = PGVisitGenerator.getStartDate();
		Test.stopTest();
		//Assertion starts here
		
	}
	

	
	

	

	
	
	static testMethod void testGenerate() {
		//Data Setup
		
		//Start the testing
		Test.startTest();
		PGVisitGenerator pGVisitGenerator_Obj = new PGVisitGenerator();
		PGVisitGenerator returnObj = PGVisitGenerator.generate();
		Test.stopTest();
		//Assertion starts here
		System.assert(returnObj!=null);
	}
	

}