public without sharing class SyncControllerTest {
    public SyncControllerTest() {
        String json = '';
        Test.setMock(HttpCalloutMock.class, new TestHttpMock(200, 'Success', json));
        Test.startTest();        
        System.enqueueJob(new KLASQueueable()); 
        Test.stopTest();

    }
}
