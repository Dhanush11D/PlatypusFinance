public with sharing class LoanService {

    private static final Decimal MIN_AMOUNT = 10000;
    private static final Decimal MAX_AMOUNT = 500000;
    private static final Integer MIN_TENURE = 3;
    private static final Integer MAX_TENURE = 53;

    private static final Map<String, Decimal> INTEREST_RATES =
        new Map<String, Decimal>{
            'Personal' => 12.00,
            'Business' => 15.00,
            'Emergency' => 18.00,
            'Education' => 8.00
        };

    public class InvalidLoanException extends Exception {}
    public class LoanAuthorizationException extends Exception {}

    public static Decimal getAnnualInterestRate(String loanSegment) {
        if (String.isBlank(loanSegment) ||
            !INTEREST_RATES.containsKey(loanSegment)) {
            throw new InvalidLoanException(
                'A valid loan segment is required.'
            );
        }

        return INTEREST_RATES.get(loanSegment);
    }

    public static Decimal calculateMonthlyInstallment(
        Decimal principal,
        Decimal annualInterestRate,
        Integer tenureMonths
    ) {
        if (principal == null || principal <= 0 ||
            annualInterestRate == null || annualInterestRate < 0 ||
            tenureMonths == null ||
            tenureMonths < MIN_TENURE ||
            tenureMonths > MAX_TENURE) {
            throw new InvalidLoanException(
                'Principal, interest rate, or tenure is invalid.'
            );
        }

        Decimal monthlyRate = annualInterestRate / 1200;

        if (monthlyRate == 0) {
            return (principal / tenureMonths)
                .setScale(2, RoundingMode.HALF_UP);
        }

        Double rate = Double.valueOf(String.valueOf(monthlyRate));
        Double amount = Double.valueOf(String.valueOf(principal));
        Double months = Double.valueOf(String.valueOf(tenureMonths));

        Double factor = Math.pow(1 + rate, months);
        Double installment = amount * rate * factor / (factor - 1);

        return Decimal.valueOf(String.valueOf(installment))
            .setScale(2, RoundingMode.HALF_UP);
    }

    @AuraEnabled
    public static Id disburseApprovedApplication(
        Id applicationId,
        Date actualDisbursementDate
    ) {
        if (applicationId == null) {
            throw new InvalidLoanException(
                'A Loan Application ID is required.'
            );
        }

        if (actualDisbursementDate == null) {
            throw new InvalidLoanException(
                'The actual disbursement date is required.'
            );
        }

        if (actualDisbursementDate > Date.today()) {
            throw new InvalidLoanException(
                'Disbursement date cannot be in the future.'
            );
        }

        List<Loan_Application__c> applications = [
            SELECT Id,
                   Customer_Account__c,
                   Applicant_Contact__c,
                   Loan_Segment__c,
                   Requested_Amount__c,
                   Requested_Tenure_Months__c,
                   Application_Status__c,
                   Eligibility_Status__c,
                   Assigned_Manager__c,
                   Approved_By__c,
                   Approved_Date__c
            FROM Loan_Application__c
            WHERE Id = :applicationId
            LIMIT 1
            FOR UPDATE
        ];

        if (applications.isEmpty()) {
            throw new InvalidLoanException(
                'Loan Application was not found or is not accessible.'
            );
        }

        Loan_Application__c application = applications[0];

        if (application.Assigned_Manager__c != UserInfo.getUserId()) {
            throw new LoanAuthorizationException(
                'Only the assigned Manager can disburse this loan.'
            );
        }

        if (application.Application_Status__c != 'Approved') {
            throw new InvalidLoanException(
                'Only approved applications can be disbursed.'
            );
        }

        if (application.Eligibility_Status__c != 'Eligible') {
            throw new InvalidLoanException(
                'The application must have an Eligible assessment before disbursement.'
            );
        }

        if (application.Approved_By__c == null ||
            application.Approved_Date__c == null) {
            throw new InvalidLoanException(
                'Approval audit details are missing.'
            );
        }

        if (application.Customer_Account__c == null ||
            application.Applicant_Contact__c == null ||
            application.Requested_Amount__c == null ||
            application.Requested_Tenure_Months__c == null) {
            throw new InvalidLoanException(
                'Required application details are missing.'
            );
        }

        if (application.Requested_Amount__c < MIN_AMOUNT ||
            application.Requested_Amount__c > MAX_AMOUNT) {
            throw new InvalidLoanException(
                'Principal must be between 10000 and 500000.'
            );
        }

        Integer tenure =
            application.Requested_Tenure_Months__c.intValue();

        if (tenure < MIN_TENURE ||
            tenure > MAX_TENURE ||
            application.Requested_Tenure_Months__c != tenure) {
            throw new InvalidLoanException(
                'Tenure must be a whole number between 3 and 53 months.'
            );
        }

        Decimal annualRate =
            getAnnualInterestRate(application.Loan_Segment__c);

        List<Loan__c> existingLoans = [
            SELECT Id
            FROM Loan__c
            WHERE Loan_Application__c = :application.Id
            LIMIT 1
        ];

        if (!existingLoans.isEmpty()) {
            throw new InvalidLoanException(
                'A loan has already been created for this application.'
            );
        }

        Decimal principal = application.Requested_Amount__c;

        Decimal installment = calculateMonthlyInstallment(
            principal,
            annualRate,
            tenure
        );

        Date firstDueDate = actualDisbursementDate.addMonths(1);
        Date maturityDate = actualDisbursementDate.addMonths(tenure);

        Loan__c loan = new Loan__c(
            Loan_Application__c = application.Id,
            Customer_Account__c = application.Customer_Account__c,
            Borrower_Contact__c = application.Applicant_Contact__c,
            Assigned_Manager__c = application.Assigned_Manager__c,
            Principal_Amount__c = principal,
            Annual_Interest_Rate__c = annualRate,
            Tenure_Months__c = tenure,
            Loan_Start_Date__c = actualDisbursementDate,
            First_Due_Date__c = firstDueDate,
            Maturity_Date__c = maturityDate,
            Loan_Status__c = 'Active',
            Disbursement_Date__c = actualDisbursementDate,
            Disbursed_Amount__c = principal,
            Disbursed_By__c = UserInfo.getUserId(),
            Total_Amount_Paid__c = 0,
            Monthly_Installment__c = installment,
            Next_Payment_Due_Date__c = firstDueDate,
            Outstanding_Balance__c = principal,
            Overdue_Amount__c = 0
        );

        insert loan;

        return loan.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Loan_Application__c> getApprovedApplications() {
        return [
            SELECT Id, Name, Customer_Account__c, Customer_Account__r.Name,
                   Applicant_Contact__c, Applicant_Contact__r.Name,
                   Loan_Segment__c, Requested_Amount__c,
                   Requested_Tenure_Months__c, Purpose_of_Loan__c,
                   Eligibility_Status__c, Application_Status__c,
                   Approved_Date__c, Approved_By__c, Approved_By__r.Name,
                   Assigned_Manager__c, Assigned_Manager__r.Name
            FROM Loan_Application__c
            WHERE Application_Status__c = 'Approved'
              AND Eligibility_Status__c = 'Eligible'
              AND Id NOT IN (SELECT Loan_Application__c FROM Loan__c WHERE Loan_Application__c != null)
            ORDER BY Approved_Date__c DESC
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Loan__c getLoan(Id loanId) {
        if (loanId == null) {
            throw new InvalidLoanException('A Loan ID is required.');
        }

        List<Loan__c> loans = [
            SELECT Id, Name, Loan_Application__c,
                   Customer_Account__c, Borrower_Contact__c,
                   Assigned_Manager__c, Principal_Amount__c,
                   Annual_Interest_Rate__c, Tenure_Months__c,
                   Loan_Start_Date__c, First_Due_Date__c,
                   Maturity_Date__c, Loan_Status__c,
                   Disbursement_Date__c, Disbursed_Amount__c,
                   Disbursed_By__c, Total_Amount_Paid__c,
                   Monthly_Installment__c,
                   Next_Payment_Due_Date__c,
                   Outstanding_Balance__c, Overdue_Amount__c
            FROM Loan__c
            WHERE Id = :loanId
            LIMIT 1
        ];

        if (loans.isEmpty()) {
            throw new InvalidLoanException(
                'Loan not found or not accessible.'
            );
        }

        return loans[0];
    }

    @AuraEnabled(cacheable=true)
    public static List<Loan__c> getCustomerLoans(Id customerAccountId) {
        if (customerAccountId == null) {
            throw new InvalidLoanException(
                'A Customer Account ID is required.'
            );
        }

        return [
            SELECT Id, Name, Loan_Application__c,
                   Customer_Account__c, Principal_Amount__c,
                   Annual_Interest_Rate__c, Tenure_Months__c,
                   Loan_Start_Date__c, Maturity_Date__c,
                   Loan_Status__c, Total_Amount_Paid__c,
                   Monthly_Installment__c,
                   Next_Payment_Due_Date__c,
                   Outstanding_Balance__c, Overdue_Amount__c
            FROM Loan__c
            WHERE Customer_Account__c = :customerAccountId
            ORDER BY Loan_Start_Date__c DESC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Loan__c> getMyAssignedLoans() {
        return [
            SELECT Id, Name, Customer_Account__c,
                   Borrower_Contact__c, Principal_Amount__c,
                   Annual_Interest_Rate__c, Tenure_Months__c,
                   Loan_Status__c, Disbursement_Date__c,
                   Monthly_Installment__c, Outstanding_Balance__c,
                   Overdue_Amount__c, Next_Payment_Due_Date__c
            FROM Loan__c
            WHERE Assigned_Manager__c = :UserInfo.getUserId()
            ORDER BY Loan_Start_Date__c DESC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static void closeLoan(Id loanId) {
        if (loanId == null) {
            throw new InvalidLoanException('A Loan ID is required.');
        }

        List<Loan__c> loans = [
            SELECT Id, Loan_Status__c, Outstanding_Balance__c,
                   Assigned_Manager__c, Next_Payment_Due_Date__c
            FROM Loan__c
            WHERE Id = :loanId
            LIMIT 1
            FOR UPDATE
        ];

        if (loans.isEmpty()) {
            throw new InvalidLoanException(
                'Loan not found or not accessible.'
            );
        }

        Loan__c loan = loans[0];

        if (loan.Assigned_Manager__c != UserInfo.getUserId()) {
            throw new LoanAuthorizationException(
                'Only the assigned Manager can close this loan.'
            );
        }

        if (loan.Loan_Status__c != 'Active') {
            throw new InvalidLoanException(
                'Only Active loans can be closed.'
            );
        }

        if (loan.Outstanding_Balance__c == null ||
            loan.Outstanding_Balance__c > 0) {
            throw new InvalidLoanException(
                'A loan cannot be closed while its outstanding balance is greater than zero.'
            );
        }

        // Preserve Next_Payment_Due_Date__c because it is required.
        loan.Loan_Status__c = 'Closed';
        update loan;
    }

    public static void cancelUndisbursedLoan(Id loanId) {
        if (loanId == null) {
            throw new InvalidLoanException('A Loan ID is required.');
        }

        List<Loan__c> loans = [
            SELECT Id, Loan_Status__c, Disbursement_Date__c,
                   Assigned_Manager__c
            FROM Loan__c
            WHERE Id = :loanId
            LIMIT 1
            FOR UPDATE
        ];

        if (loans.isEmpty()) {
            throw new InvalidLoanException(
                'Loan not found or not accessible.'
            );
        }

        Loan__c loan = loans[0];

        if (loan.Assigned_Manager__c != UserInfo.getUserId()) {
            throw new LoanAuthorizationException(
                'Only the assigned Manager can cancel this loan.'
            );
        }

        if (loan.Disbursement_Date__c != null ||
            loan.Loan_Status__c == 'Active' ||
            loan.Loan_Status__c == 'Closed') {
            throw new InvalidLoanException(
                'A disbursed, Active, or Closed loan cannot be cancelled as undisbursed.'
            );
        }

        if (loan.Loan_Status__c != 'Pending Disbursement') {
            throw new InvalidLoanException(
                'Only loans Pending Disbursement can be cancelled.'
            );
        }

        loan.Loan_Status__c = 'Cancelled';
        update loan;
    }
}