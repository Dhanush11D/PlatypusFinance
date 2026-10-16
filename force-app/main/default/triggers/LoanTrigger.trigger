trigger LoanTrigger on Loan__c (before insert, before update) {

    for (Loan__c loan : Trigger.new) {

        // Validate principal amount.
        if (loan.Principal_Amount__c != null &&
            (loan.Principal_Amount__c < 10000 ||
             loan.Principal_Amount__c > 500000)) {
            loan.Principal_Amount__c.addError(
                'Loan principal must be between ₹10,000 and ₹5,00,000.'
            );
        }

        // Validate tenure.
        if (loan.Tenure_Months__c != null &&
            (loan.Tenure_Months__c < 3 ||
             loan.Tenure_Months__c > 53)) {
            loan.Tenure_Months__c.addError(
                'Loan tenure must be between 3 and 53 months.'
            );
        }

        // Validate interest rate.
        if (loan.Annual_Interest_Rate__c != null &&
            (loan.Annual_Interest_Rate__c < 0 ||
             loan.Annual_Interest_Rate__c > 100)) {
            loan.Annual_Interest_Rate__c.addError(
                'Annual interest rate must be between 0% and 100%.'
            );
        }

        // Validate financial summary values.
        if (loan.Total_Amount_Paid__c != null &&
            loan.Total_Amount_Paid__c < 0) {
            loan.Total_Amount_Paid__c.addError(
                'Total amount paid cannot be negative.'
            );
        }

        if (loan.Outstanding_Balance__c != null &&
            loan.Outstanding_Balance__c < 0) {
            loan.Outstanding_Balance__c.addError(
                'Outstanding balance cannot be negative.'
            );
        }

        if (loan.Overdue_Amount__c != null &&
            loan.Overdue_Amount__c < 0) {
            loan.Overdue_Amount__c.addError(
                'Overdue amount cannot be negative.'
            );
        }

        if (loan.Disbursed_Amount__c != null &&
            loan.Disbursed_Amount__c < 0) {
            loan.Disbursed_Amount__c.addError(
                'Disbursed amount cannot be negative.'
            );
        }

        // Validate the start and maturity dates.
        if (loan.Loan_Start_Date__c != null &&
            loan.Maturity_Date__c != null &&
            loan.Maturity_Date__c < loan.Loan_Start_Date__c) {
            loan.Maturity_Date__c.addError(
                'Maturity Date cannot be before Loan Start Date.'
            );
        }

        if (loan.Loan_Start_Date__c != null &&
            loan.First_Due_Date__c != null &&
            loan.First_Due_Date__c < loan.Loan_Start_Date__c) {
            loan.First_Due_Date__c.addError(
                'First Due Date cannot be before Loan Start Date.'
            );
        }

        // Active loans must have disbursement details.
        if (loan.Loan_Status__c == 'Active') {
            if (loan.Disbursement_Date__c == null) {
                loan.Disbursement_Date__c.addError(
                    'An Active loan must have a Disbursement Date.'
                );
            }

            if (loan.Disbursed_Amount__c == null ||
                loan.Disbursed_Amount__c <= 0) {
                loan.Disbursed_Amount__c.addError(
                    'An Active loan must have a positive Disbursed Amount.'
                );
            }

            if (loan.Disbursed_By__c == null) {
                loan.Disbursed_By__c.addError(
                    'An Active loan must have a Disbursed By user.'
                );
            }

            if (loan.Loan_Start_Date__c == null) {
                loan.Loan_Start_Date__c.addError(
                    'An Active loan must have a Loan Start Date.'
                );
            }
        }

        // A closed loan must be fully repaid.
        if (loan.Loan_Status__c == 'Closed' &&
            loan.Outstanding_Balance__c != null &&
            loan.Outstanding_Balance__c > 0) {
            loan.Loan_Status__c.addError(
                'A loan cannot be Closed while an outstanding balance remains.'
            );
        }

        // If an existing loan is disbursed, prevent clearing its audit data.
        if (Trigger.isUpdate) {
            Loan__c oldLoan = Trigger.oldMap.get(loan.Id);

            Boolean wasDisbursed =
                oldLoan.Disbursement_Date__c != null ||
                oldLoan.Disbursed_By__c != null;

            if (wasDisbursed &&
                loan.Disbursement_Date__c == null) {
                loan.Disbursement_Date__c.addError(
                    'Disbursement Date cannot be cleared after disbursement.'
                );
            }

            if (wasDisbursed &&
                loan.Disbursed_By__c == null) {
                loan.Disbursed_By__c.addError(
                    'Disbursed By cannot be cleared after disbursement.'
                );
            }
        }
    }
}