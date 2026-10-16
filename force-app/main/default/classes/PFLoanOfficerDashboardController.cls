public without sharing class PFLoanOfficerDashboardController {

    public class DashboardMetrics {
        @AuraEnabled public Integer totalApplications { get; set; }
        @AuraEnabled public Integer pendingReview { get; set; }
        @AuraEnabled public Integer approvedApplications { get; set; }
        @AuraEnabled public Integer rejectedApplications { get; set; }
        @AuraEnabled public Decimal totalRequestedAmount { get; set; }
    }

    public class ApplicationRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String applicationNumber { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String segment { get; set; }
        @AuraEnabled public Decimal requestedAmount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date applicationDate { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static DashboardMetrics getDashboardMetrics() {
        DashboardMetrics result = new DashboardMetrics();
        result.totalApplications = 0;
        result.pendingReview = 0;
        result.approvedApplications = 0;
        result.rejectedApplications = 0;
        result.totalRequestedAmount = 0;

        for (AggregateResult item : [
            SELECT Application_Status__c statusValue,
                   COUNT(Id) recordCount,
                   SUM(Requested_Amount__c) requestedTotal
            FROM Loan_Application__c
            GROUP BY Application_Status__c
        ]) {
            Integer countValue = (Integer) item.get('recordCount');
            String statusValue = (String) item.get('statusValue');
            Decimal amountValue = (Decimal) item.get('requestedTotal');

            result.totalApplications += countValue;

            if (amountValue != null) {
                result.totalRequestedAmount += amountValue;
            }

            if (statusValue == 'Submitted' ||
                statusValue == 'Under Review') {
                result.pendingReview += countValue;
            } else if (statusValue == 'Approved') {
                result.approvedApplications += countValue;
            } else if (statusValue == 'Rejected') {
                result.rejectedApplications += countValue;
            }
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<ApplicationRow> getRecentApplications() {
        List<ApplicationRow> results = new List<ApplicationRow>();

        for (Loan_Application__c application : [
            SELECT Id, Name, Customer_Account__r.Name,
                   Loan_Segment__c, Requested_Amount__c,
                   Application_Status__c, Application_Date__c
            FROM Loan_Application__c
            ORDER BY CreatedDate DESC
            LIMIT 10
        ]) {
            ApplicationRow row = new ApplicationRow();
            row.id = application.Id;
            row.applicationNumber = application.Name;
            row.customerName = application.Customer_Account__r == null
                ? 'No customer linked'
                : application.Customer_Account__r.Name;
            row.segment = application.Loan_Segment__c;
            row.requestedAmount = application.Requested_Amount__c;
            row.status = application.Application_Status__c;
            row.applicationDate = application.Application_Date__c;
            results.add(row);
        }

        return results;
    }
}