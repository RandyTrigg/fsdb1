// Cron schedule strings
String hourly = '0 0 * * * ?';
String daily1am = '0 0 1 * * ?';
String daily2am = '0 0 2 * * ?';
String daily3am = '0 0 3 * * ?';
String daily4am = '0 0 4 * * ?';
String tueFri1am = '0 0 1 ? * TUE,FRI';
String monthly15 = '0 0 1 15 * ?';
String monthlyL = '0 0 1 L * ?';

// Mapping of schedule names to cron schedule strings
// Normally name = the name of the schedule class. 
// However, a suffix starting with an underscore indicates a variant, allowing multiple schedules to use the same base class name.
Map<String, String> nameToSched = new Map<String, String> {
    'Sync_QueueableSchedule' => hourly // daily1am
};

// Fetch active cron triggers
List<CronTrigger> crons = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CreatedBy.Name = 'Randy Trigg' OR CreatedBy.Name = 'Karen Ishimaru'
];
Map<String, CronTrigger> cronsMap = new Map<String, CronTrigger>();
for (CronTrigger ct : crons) cronsMap.put(ct.CronJobDetail.Name, ct);

// Refresh the cron triggers.
for (String name : nameToSched.keySet()) {
    // Abort the cron job with given name, if any.
    CronTrigger ct = cronsMap.get(name);
    // if (ct != null) System.abortjob(ct.Id);
    // [Comment out following lines in order to shut down all scheduled jobs temporarily (e.g. for Affinaquest upgrade).]
    // Fire up a new cron for the schedule class using appropriate schedule.
    // Classname is the name minus the underscore suffix (indicating a variant) if any
    Integer underscoreLoc = name.indexOf('_');
    String className = underscoreLoc >= 0 ? name.left(underscoreLoc) : name;
    Type t = Type.forName(className);
    Schedulable schedInstance = (Schedulable)t.newInstance();
    system.debug(JSON.serialize(schedInstance));
    Id jobId = System.Schedule(name, nameToSched.get(name), schedInstance);
}