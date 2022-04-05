// Batch process used to reset letters when the number is over a threshold.
global with sharing class LetterResetBatch implements Database.Batchable<Id>, Database.Stateful {
    global final List<Id> letIds;
    global List<Id> unprocessedLetIds = new List<Id>();
    global Boolean emailOnCompletionFlg;

    global LetterResetBatch(Set<Id> ids, Boolean emailFlg) {
        letIds = new List<Id>(ids);
        emailOnCompletionFlg = emailFlg;
    }

    global Iterable<Id> start(Database.BatchableContext BC) {
        return letIds;
    }

    global void execute(Database.BatchableContext BC, List<Id> scope) {
        // Reset letters gathering ids of those that can't be processed.
        if (scope.size() > 0) {
            LetterReset lr = new LetterReset();
            unprocessedLetIds.addAll(
                lr.resetLettersHandler(new Set<Id>(scope))
            );
        }
    }

    global void finish(Database.BatchableContext BC) {
        AsyncApexJob a = [
            SELECT
                Id,
                Status,
                NumberOfErrors,
                JobItemsProcessed,
                TotalJobItems,
                CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :BC.getJobId()
        ];
        system.debug(
            'LetterResetBatch finish: unprocessedLetIds = ' +
            JSON.serialize(unprocessedLetIds)
        );
        system.debug('LetterResetBatch finish: a = ' + JSON.serialize(a));
        // Send an email notifying of completion and any unprocessed letters.
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        // Recipient is current user if non-community user, else IM.
        String toEmail = Utilities.currentUserProfileName()
                .toLowerCase()
                .contains('community member')
            ? Utilities.EmailAddressIM
            : a.CreatedBy.Email;
        mail.setToAddresses(new List<String>{ toEmail });
        mail.setSenderDisplayName('Reset letters complete');
        mail.setSubject('Reset of ' + letIds.size() + ' letters complete');
        String body;
        if (a.NumberOfErrors > 0) {
            // There were errors processing this batch.
            body =
                'The batch Apex job processed ' +
                a.TotalJobItems +
                ' batches with ' +
                a.NumberOfErrors +
                ' failures.' +
                ' Please check with a Salesforce administrator.';
            // Send error email to IM.
            Utilities.BatchErrorEmail('LetterReset', a);
        } else if (unprocessedLetIds.size() == 1) {
            // One letter couldn't be reset.
            body =
                'One of the ' +
                letIds.size() +
                ' letters could not be reset, because it has non-blank Date Sent: ' +
                (String) unprocessedLetIds[0];
        } else if (unprocessedLetIds.size() > 1) {
            // Multiple letters couldn't be reset.
            body =
                unprocessedLetIds.size() +
                ' out of ' +
                letIds.size() +
                ' letters could not be reset, because they have non-blank Date Sent: ' +
                String.join(unprocessedLetIds, ', ');
        } else {
            body = 'All ' + letIds.size() + ' letters were successfully reset.';
            if (emailOnCompletionFlg)
                LetterController.emailLetters0(new Set<Id>(letIds));
        }
        if (body != null) {
            mail.setPlainTextBody(body);
            if (!Test.isRunningTest()) {
                // Don't try to send email if under test method.
                Messaging.sendEmail(
                    new List<Messaging.SingleEmailMessage>{ mail }
                );
            }
        }
    }
}