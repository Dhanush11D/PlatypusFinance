PFLoanOfficerDashboardController.DashboardMetrics metrics = PFLoanOfficerDashboardController.getDashboardMetrics();
System.debug('TOTAL_APPS: ' + metrics.totalApplications);
System.debug('PENDING_REVIEW: ' + metrics.pendingReview);
System.debug('APPROVED: ' + metrics.approvedApplications);
System.debug('REJECTED: ' + metrics.rejectedApplications);
System.debug('TOTAL_REQUESTED: ' + metrics.totalRequestedAmount);

List<PFLoanOfficerDashboardController.ApplicationRow> recent = PFLoanOfficerDashboardController.getRecentApplications();
System.debug('RECENT_APPS_COUNT: ' + recent.size());
for (PFLoanOfficerDashboardController.ApplicationRow r : recent) {
    System.debug('ROW: ' + r.applicationNumber + ' | ' + r.customerName + ' | ' + r.status + ' | ' + r.requestedAmount);
}
