trigger LoanApplicationTrigger on Loan_Application__c (
    before insert,
    before update
) {
    Set<Id> accountIds = new Set<Id>();
    Set<Id> contactIds = new Set<Id>();

    for (Loan_Application__c application : Trigger.new) {
        if (application.Customer_Account__c != null) {
            accountIds.add(application.Customer_Account__c);
        }

        if (application.Applicant_Contact__c != null) {
            contactIds.add(application.Applicant_Contact__c);
        }
    }

    Map<Id, Account> accountsById = new Map<Id, Account>();
    Map<Id, Contact> contactsById = new Map<Id, Contact>();

    if (!accountIds.isEmpty()) {
        accountsById = new Map<Id, Account>([
            SELECT Id, Customer_Status__c
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }

    if (!contactIds.isEmpty()) {
        contactsById = new Map<Id, Contact>([
            SELECT Id, AccountId
            FROM Contact
            WHERE Id IN :contactIds
        ]);
    }

    for (Loan_Application__c application : Trigger.new) {
        Boolean progressingApplication =
            application.Application_Status__c == 'Submitted' ||
            application.Application_Status__c == 'Under Review' ||
            application.Application_Status__c == 'Approved';

        // Validate an entered amount, including on Draft records.
        if (application.Requested_Amount__c != null &&
            (application.Requested_Amount__c < 10000 ||
             application.Requested_Amount__c > 500000)) {
            application.Requested_Amount__c.addError(
                'Requested loan amount must be between ₹10,000 and ₹5,00,000.'
            );
        }

        // Validate an entered tenure, including on Draft records.
        if (application.Requested_Tenure_Months__c != null &&
            (application.Requested_Tenure_Months__c < 3 ||
             application.Requested_Tenure_Months__c > 53)) {
            application.Requested_Tenure_Months__c.addError(
                'Requested tenure must be between 3 and 53 months.'
            );
        }

        // Contact must belong to the selected customer account.
        if (application.Customer_Account__c != null &&
            application.Applicant_Contact__c != null &&
            contactsById.containsKey(
                application.Applicant_Contact__c
            )) {
            Contact applicant =
                contactsById.get(application.Applicant_Contact__c);

            if (applicant.AccountId != application.Customer_Account__c) {
                application.Applicant_Contact__c.addError(
                    'The applicant Contact must belong to the selected Customer Account.'
                );
            }
        }

        // Submitted and later-stage applications must be complete.
        if (progressingApplication) {
            if (application.Customer_Account__c == null) {
                application.Customer_Account__c.addError(
                    'Select a Customer Account before submitting the application.'
                );
            }

            if (application.Applicant_Contact__c == null) {
                application.Applicant_Contact__c.addError(
                    'Select an Applicant Contact before submitting the application.'
                );
            }

            if (application.Application_Date__c == null) {
                application.Application_Date__c.addError(
                    'Application Date is required before submission.'
                );
            }

            if (String.isBlank(application.Loan_Segment__c)) {
                application.Loan_Segment__c.addError(
                    'Loan Segment is required before submission.'
                );
            }

            if (application.Requested_Amount__c == null) {
                application.Requested_Amount__c.addError(
                    'Requested Amount is required before submission.'
                );
            }

            if (application.Requested_Tenure_Months__c == null) {
                application.Requested_Tenure_Months__c.addError(
                    'Requested Tenure is required before submission.'
                );
            }

            if (String.isBlank(application.Purpose_of_Loan__c)) {
                application.Purpose_of_Loan__c.addError(
                    'Purpose of Loan is required before submission.'
                );
            }

            // Block applications progressing for inactive or blocked customers.
            if (application.Customer_Account__c != null &&
                accountsById.containsKey(
                    application.Customer_Account__c
                )) {
                Account customer =
                    accountsById.get(application.Customer_Account__c);

                if (customer.Customer_Status__c == 'Blocked' ||
                    customer.Customer_Status__c == 'Inactive') {
                    application.Customer_Account__c.addError(
                        'Applications cannot proceed for Blocked or Inactive customers.'
                    );
                }
            }
        }
    }
}