public with sharing class LoanApplicationService {

    // =========================================================
    // BUSINESS CONFIGURATION
    // =========================================================

    private static final Decimal MIN_AMOUNT = 10000;
    private static final Decimal MAX_AMOUNT = 500000;
    private static final Integer MIN_TENURE = 3;
    private static final Integer MAX_TENURE = 53;

    private static final Map<String, Decimal> INTEREST_RATES =
        new Map<String, Decimal>{
            'Personal'  => 12.00,
            'Business'  => 15.00,
            'Emergency' => 18.00,
            'Education' => 8.00
        };

    private static final Set<String> REJECTION_REASONS =
        new Set<String>{
            'Insufficient Income',
            'Eligibility Criteria Not Met',
            'Incomplete Documentation',
            'High Risk',
            'Other'
        };

    // =========================================================
    // EXCEPTIONS
    // =========================================================

    public class InvalidLoanSegmentException extends Exception {}
    public class InvalidApplicationException extends Exception {}
    public class LoanAuthorizationException extends Exception {}

    // =========================================================
    // INTEREST RATE
    // =========================================================

    public static Decimal getAnnualInterestRate(String loanSegment) {
        if (String.isBlank(loanSegment) ||
            !INTEREST_RATES.containsKey(loanSegment)) {
            throw new InvalidLoanSegmentException(
                'Invalid loan segment: ' + loanSegment
            );
        }

        return INTEREST_RATES.get(loanSegment);
    }

    // =========================================================
    // APPLICATION RETRIEVAL
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static Loan_Application__c getApplication(Id applicationId) {
        if (applicationId == null) {
            throw new InvalidApplicationException(
                'A Loan Application ID is required.'
            );
        }

        List<Loan_Application__c> records = [
            SELECT Id, Name,
                   Customer_Account__c,
                   Customer_Account__r.Name,
                   Customer_Account__r.Customer_Status__c,
                   Customer_Account__r.KYC_Status__c,
                   Customer_Account__r.Risk_Category__c,
                   Applicant_Contact__c,
                   Applicant_Contact__r.Name,
                   Applicant_Contact__r.Monthly_Income__c,
                   Applicant_Contact__r.Email,
                   Applicant_Contact__r.Phone,
                   Application_Date__c,
                   Loan_Segment__c,
                   Requested_Amount__c,
                   Requested_Tenure_Months__c,
                   Purpose_of_Loan__c,
                   Application_Status__c,
                   Approval_Stage__c,
                   Eligibility_Status__c,
                   Monthly_Income_Snapshot__c,
                   Assigned_Manager__c,
                   Assigned_Manager__r.Name,
                   Decision_Comments__c,
                   Rejection_Reason__c,
                   Approved_By__c,
                   Approved_By__r.Name,
                   Approved_Date__c,
                   Rejected_By__c,
                   Rejected_By__r.Name,
                   Rejected_Date__c
            FROM Loan_Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new InvalidApplicationException(
                'Loan Application not found or not accessible.'
            );
        }

        return records[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<Loan_Application__c> getMyAssignedApplications() {
        return [
            SELECT Id, Name,
                   Customer_Account__c,
                   Customer_Account__r.Name,
                   Applicant_Contact__c,
                   Applicant_Contact__r.Name,
                   Application_Date__c,
                   Loan_Segment__c,
                   Requested_Amount__c,
                   Requested_Tenure_Months__c,
                   Application_Status__c,
                   Approval_Stage__c,
                   Eligibility_Status__c,
                   Assigned_Manager__c
            FROM Loan_Application__c
            WHERE Assigned_Manager__c = :UserInfo.getUserId()
            ORDER BY Application_Date__c DESC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Loan_Application__c> getApplicationsForReview() {
        return [
            SELECT Id, Name,
                   Customer_Account__c, Customer_Account__r.Name,
                   Customer_Account__r.Customer_Status__c,
                   Customer_Account__r.KYC_Status__c,
                   Customer_Account__r.Risk_Category__c,
                   Applicant_Contact__c, Applicant_Contact__r.Name,
                   Applicant_Contact__r.Monthly_Income__c,
                   Application_Date__c,
                   Loan_Segment__c,
                   Requested_Amount__c,
                   Requested_Tenure_Months__c,
                   Purpose_of_Loan__c,
                   Application_Status__c,
                   Approval_Stage__c,
                   Eligibility_Status__c,
                   Monthly_Income_Snapshot__c,
                   Assigned_Manager__c, Assigned_Manager__r.Name
            FROM Loan_Application__c
            WHERE Application_Status__c IN ('Submitted', 'Under Review')
            ORDER BY Application_Date__c DESC, CreatedDate DESC
            LIMIT 200
        ];
    }

    // =========================================================
    // APPLICATION VALIDATION
    // =========================================================

    public static void validateApplication(Id applicationId) {
        validateApplicationRecord(getApplication(applicationId));
    }

    private static void validateApplicationRecord(
        Loan_Application__c application
    ) {
        if (application.Customer_Account__c == null) {
            throw new InvalidApplicationException(
                'Customer Account is required.'
            );
        }

        if (application.Applicant_Contact__c == null) {
            throw new InvalidApplicationException(
                'Applicant Contact is required.'
            );
        }

        if (application.Application_Date__c == null) {
            throw new InvalidApplicationException(
                'Application Date is required.'
            );
        }

        if (String.isBlank(application.Loan_Segment__c) ||
            !INTEREST_RATES.containsKey(application.Loan_Segment__c)) {
            throw new InvalidApplicationException(
                'A valid Loan Segment is required.'
            );
        }

        if (application.Requested_Amount__c == null ||
            application.Requested_Amount__c < MIN_AMOUNT ||
            application.Requested_Amount__c > MAX_AMOUNT) {
            throw new InvalidApplicationException(
                'Requested Amount must be between 10000 and 500000.'
            );
        }

        if (application.Requested_Tenure_Months__c == null ||
            application.Requested_Tenure_Months__c < MIN_TENURE ||
            application.Requested_Tenure_Months__c > MAX_TENURE ||
            application.Requested_Tenure_Months__c !=
                application.Requested_Tenure_Months__c.intValue()) {
            throw new InvalidApplicationException(
                'Requested Tenure must be a whole number between 3 and 53 months.'
            );
        }

        if (String.isBlank(application.Purpose_of_Loan__c)) {
            throw new InvalidApplicationException(
                'Purpose of Loan is required.'
            );
        }

        List<Account> customers = [
            SELECT Id, Customer_Status__c
            FROM Account
            WHERE Id = :application.Customer_Account__c
            LIMIT 1
        ];

        if (customers.isEmpty()) {
            throw new InvalidApplicationException(
                'The selected customer account could not be found.'
            );
        }

        if (customers[0].Customer_Status__c == 'Blocked' ||
            customers[0].Customer_Status__c == 'Inactive') {
            throw new InvalidApplicationException(
                'Blocked or inactive customers cannot proceed.'
            );
        }

        List<Contact> applicants = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id = :application.Applicant_Contact__c
            LIMIT 1
        ];

        if (applicants.isEmpty()) {
            throw new InvalidApplicationException(
                'The selected applicant contact could not be found.'
            );
        }

        if (applicants[0].AccountId != application.Customer_Account__c) {
            throw new InvalidApplicationException(
                'Applicant Contact must belong to the selected Customer Account.'
            );
        }
    }

    // =========================================================
    // SUBMISSION
    // =========================================================

    @AuraEnabled
    public static void submitApplication(Id applicationId) {
        Loan_Application__c application =
            getApplicationForUpdate(applicationId);

        if (application.Application_Status__c != 'Draft') {
            throw new InvalidApplicationException(
                'Only Draft applications can be submitted.'
            );
        }

        validateApplicationRecord(application);

        Contact applicant = [
            SELECT Id, Monthly_Income__c
            FROM Contact
            WHERE Id = :application.Applicant_Contact__c
            LIMIT 1
        ];

        application.Monthly_Income_Snapshot__c =
            applicant.Monthly_Income__c;
        application.Application_Status__c = 'Submitted';
        application.Approval_Stage__c = 'Manager Review';

        update application;
    }

    // =========================================================
    // PRELIMINARY ELIGIBILITY
    // =========================================================

    @AuraEnabled
    public static String assessEligibility(Id applicationId) {
        Loan_Application__c application =
            getApplicationForUpdate(applicationId);

        if (application.Application_Status__c != 'Submitted' &&
            application.Application_Status__c != 'Under Review') {
            throw new InvalidApplicationException(
                'Eligibility can only be assessed for Submitted or Under Review applications.'
            );
        }

        String result = 'Manual Review';

        try {
            validateApplicationRecord(application);

            Account customer = [
                SELECT Id, KYC_Status__c, Risk_Category__c,
                       Customer_Status__c
                FROM Account
                WHERE Id = :application.Customer_Account__c
                LIMIT 1
            ];

            Contact applicant = [
                SELECT Id, Monthly_Income__c
                FROM Contact
                WHERE Id = :application.Applicant_Contact__c
                LIMIT 1
            ];

            if (customer.Customer_Status__c == 'Blocked' ||
                customer.Customer_Status__c == 'Inactive') {
                result = 'Ineligible';
            } else if (customer.KYC_Status__c != 'Verified' ||
                       customer.Risk_Category__c == 'High' ||
                       applicant.Monthly_Income__c == null ||
                       applicant.Monthly_Income__c <= 0) {
                result = 'Manual Review';
            } else {
                // Credit affordability policy is not yet configured.
                // A Manager must complete the review before approval.
                result = 'Manual Review';
            }
        } catch (InvalidApplicationException ex) {
            result = 'Ineligible';
        }

        application.Eligibility_Status__c = result;
        update application;

        return result;
    }

    // =========================================================
    // MANAGER ASSIGNMENT
    // =========================================================

    @AuraEnabled
    public static void assignManager(
        Id applicationId,
        Id managerUserId
    ) {
        if (applicationId == null || managerUserId == null) {
            throw new InvalidApplicationException(
                'Application ID and Manager User ID are required.'
            );
        }

        List<User> managers = [
            SELECT Id, IsActive
            FROM User
            WHERE Id = :managerUserId
            LIMIT 1
        ];

        if (managers.isEmpty() || !managers[0].IsActive) {
            throw new InvalidApplicationException(
                'The selected Manager user does not exist or is inactive.'
            );
        }

        Loan_Application__c application =
            getApplicationForUpdate(applicationId);

        if (application.Application_Status__c != 'Submitted' &&
            application.Application_Status__c != 'Under Review') {
            throw new InvalidApplicationException(
                'A Manager can only be assigned to a Submitted or Under Review application.'
            );
        }

        application.Assigned_Manager__c = managerUserId;
        update application;
    }

    // =========================================================
    // MANAGER REVIEW
    // =========================================================

    @AuraEnabled
    public static void startReview(Id applicationId) {
        Loan_Application__c application =
            getApplicationForUpdate(applicationId);

        requireAssignedManager(application);

        if (application.Application_Status__c != 'Submitted') {
            throw new InvalidApplicationException(
                'Only Submitted applications can enter Manager review.'
            );
        }

        application.Application_Status__c = 'Under Review';
        application.Approval_Stage__c = 'Manager Review';

        update application;
    }

    // =========================================================
    // APPROVAL
    // =========================================================

    @AuraEnabled
    public static void approveApplication(Id applicationId) {
        decideApplication(applicationId, true, null, null);
    }

    // =========================================================
    // REJECTION
    // =========================================================

    @AuraEnabled
    public static void rejectApplication(
        Id applicationId,
        String rejectionReason,
        String decisionComments
    ) {
        if (String.isBlank(rejectionReason) ||
            !REJECTION_REASONS.contains(rejectionReason)) {
            throw new InvalidApplicationException(
                'A valid rejection reason is required.'
            );
        }

        decideApplication(
            applicationId,
            false,
            rejectionReason,
            decisionComments
        );
    }

    private static void decideApplication(
        Id applicationId,
        Boolean approve,
        String rejectionReason,
        String decisionComments
    ) {
        Loan_Application__c application =
            getApplicationForUpdate(applicationId);

        requireAssignedManager(application);

        if (application.Application_Status__c != 'Under Review') {
            throw new InvalidApplicationException(
                'Only applications Under Review can receive a decision.'
            );
        }

        validateApplicationRecord(application);

        if (approve &&
            application.Eligibility_Status__c != 'Eligible') {
            throw new InvalidApplicationException(
                'Approval requires an Eligible assessment. Financial eligibility policy must be completed before an application can be marked Eligible.'
            );
        }

        if (application.Eligibility_Status__c == 'Ineligible') {
            throw new InvalidApplicationException(
                'An Ineligible application cannot receive an approval or rejection through this decision method.'
            );
        }

        application.Approval_Stage__c = 'Decision Complete';
        application.Decision_Comments__c = decisionComments;

        if (approve) {
            application.Application_Status__c = 'Approved';
            application.Approved_By__c = UserInfo.getUserId();
            application.Approved_Date__c = System.now();
            application.Rejection_Reason__c = null;
            application.Rejected_By__c = null;
            application.Rejected_Date__c = null;
        } else {
            application.Application_Status__c = 'Rejected';
            application.Rejection_Reason__c = rejectionReason;
            application.Rejected_By__c = UserInfo.getUserId();
            application.Rejected_Date__c = System.now();
            application.Approved_By__c = null;
            application.Approved_Date__c = null;
        }

        update application;
    }

    // =========================================================
    // WITHDRAWAL
    // =========================================================

    @AuraEnabled
    public static void withdrawApplication(Id applicationId) {
        Loan_Application__c application =
            getApplicationForUpdate(applicationId);

        if (application.Application_Status__c != 'Draft' &&
            application.Application_Status__c != 'Submitted') {
            throw new InvalidApplicationException(
                'Only Draft or Submitted applications can be withdrawn.'
            );
        }

        application.Application_Status__c = 'Withdrawn';
        update application;
    }

    // =========================================================
    // SHARED PRIVATE HELPERS
    // =========================================================

    private static Loan_Application__c getApplicationForUpdate(
        Id applicationId
    ) {
        if (applicationId == null) {
            throw new InvalidApplicationException(
                'A Loan Application ID is required.'
            );
        }

        List<Loan_Application__c> records = [
            SELECT Id, Name,
                   Customer_Account__c,
                   Applicant_Contact__c,
                   Application_Date__c,
                   Loan_Segment__c,
                   Requested_Amount__c,
                   Requested_Tenure_Months__c,
                   Purpose_of_Loan__c,
                   Application_Status__c,
                   Approval_Stage__c,
                   Eligibility_Status__c,
                   Monthly_Income_Snapshot__c,
                   Assigned_Manager__c,
                   Decision_Comments__c,
                   Rejection_Reason__c,
                   Approved_By__c,
                   Approved_Date__c,
                   Rejected_By__c,
                   Rejected_Date__c
            FROM Loan_Application__c
            WHERE Id = :applicationId
            LIMIT 1
            FOR UPDATE
        ];

        if (records.isEmpty()) {
            throw new InvalidApplicationException(
                'Loan Application not found or not accessible.'
            );
        }

        return records[0];
    }

    private static void requireAssignedManager(
        Loan_Application__c application
    ) {
        if (application.Assigned_Manager__c == null ||
            application.Assigned_Manager__c != UserInfo.getUserId()) {
            throw new LoanAuthorizationException(
                'Only the Manager assigned to this application can perform this action.'
            );
        }
    }
}
