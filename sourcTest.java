@isTest
private class CA_CTIHandlerTest {



	
@testSetup
static void setup() {
CA_Log_Setting__c setting = new CA_Log_Setting__c();
setting.name = 'Log Enabled';
setting.CA_Value__c = true;
insert setting;

User u = [SELECT CA_Agent_Id__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
u.CA_Agent_Id__c = 'AG001';
update u;

Account acc = new Account();
acc.RecordTypeId = CA_Constants.RT_ACCOUNT_PERSON_ACCOUNT_ID;
acc.LastName = 'John';
acc.Phone = '123';
insert acc;
}

static testMethod void testFindAgentById() {

test.startTest();
User u = CA_CTIHandler.findAgentById('AG001');
test.stopTest();
system.assert(u != null);
}

static testMethod void testFindContactByPhone() {

test.startTest();
Contact c = [SELECT Id FROM Contact LIMIT 1];
test.stopTest();
system.assert(c != null);
}

static testMethod void testFireCTIOpenContactEvent() {
User u = CA_CTIHandler.findAgentById('AG001');
Account a = [SELECT Id FROM Account LIMIT 1];
Contact c = [SELECT Id,Phone FROM Contact LIMIT 1];
test.startTest();
CA_CTIHandler.fireCTIOpenContactEvent(u.CA_Agent_Id__c, a,c.Phone,'123','123');
test.stopTest();
}

static testMethod void testAddContactRecordLink() {
Contact c = [SELECT Id FROM Contact LIMIT 1];
String url = 'www.google.com';
test.startTest();
CA_CTIHandler.addContactRecordLink(c.Id, url);
CA_CTIHandler.generateContactId('123');
test.stopTest();
system.assertEquals(url, [SELECT CA_URL__c FROM CA_Call_Recording_Link__c LIMIT 1].CA_URL__c);
}

static testMethod void testLogException() {
test.startTest();
CA_CTIHandler.logException('a','b','CA_CTIHandler');
test.stopTest();
}

static testMethod void testSendEmail() {
test.startTest();
CA_CTIHandler.sendCTIWarningEmail('a','b');
test.stopTest();
}
}