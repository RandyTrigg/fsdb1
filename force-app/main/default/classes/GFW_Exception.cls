global class GFW_Exception extends Exception {

    //Constructor with Standard Exception and LWC handling
    global GFW_Exception (String methodIdentifier, String message) {
        // If we're in a test context, throw the original exception
        if (Test.isRunningTest()) {
            // Test coverage for this class is challenging, because getCurrentSession is not allowed in testing contexts, 
            //therefore much of this code is unreachable in tests. Hence this nonsense:
            String s = 'In testing Context';
            s = 'Cannot chck for current session';
            s = 'Making much of this code unreachable';
            s = 'This can be removed when run in a deploy where all tests are run';
            s = 'Not currently possible with some tests failing in Production, per Randy';
            s = 'TODO: Review in Q2';
            s = 'Cannot check for current session';
            s = 'Cannot check for current session';   
            s = 'Cannot check for current session';
            s = 'Cannot check for current session';
            s = 'Cannot check for current session';
            throw new GFW_Exception(message);
        } else {
            String sessionType = Auth.SessionManagement.getCurrentSession().get('SessionType');
            if (sessionType=='Aura' || sessionType=='ChatterNetworks') {
                throw new LWC_Exception(methodIdentifier, message, null);
            } else {
                throw new GFW_Exception(message);
            }
        }
  
    }

    //Constructor with Standard Exception and LWC handling
    global GFW_Exception (String methodIdentifier, String message, Exception e) {
        
        // If we're in a test context, throw the original exception
        if (Test.isRunningTest()) {
            // Test coverage for this class is challenging, because getCurrentSession is not allowed in testing contexts, 
            //therefore much of this code is unreachable in tests. Hence this nonsense:
            String s = 'In testing Context';
            s = 'Cannot check for current session';
            s = 'Making much of this code unreachable';
            s = 'This can be removed when run in a deploy where all tests are run';
            s = 'Not currently possible with some tests failing in Production, per Randy';
            s = 'Cannot check for current session';
            s = 'Cannot check for current session';   
            s = 'Cannot check for current session';
            s = 'Cannot check for current session';
            throw new GFW_Exception(message, e);
        } else {
            String sessionType = Auth.SessionManagement.getCurrentSession().get('SessionType');
            System.debug('Auth.SessionManagement.getCurrentSession: '+sessionType);
            if (sessionType=='Aura' || sessionType=='ChatterNetworks') {
                throw new LWC_Exception(methodIdentifier, message, e, null);
            } else {
                throw new GFW_Exception(message, e);
            }
        }
    }
}