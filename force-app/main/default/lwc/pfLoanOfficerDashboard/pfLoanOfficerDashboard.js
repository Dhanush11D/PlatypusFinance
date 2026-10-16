import { LightningElement, wire } from 'lwc';
import Id from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';

import getDashboardMetrics from
    '@salesforce/apex/PFLoanOfficerDashboardController.getDashboardMetrics';
import getRecentApplications from
    '@salesforce/apex/PFLoanOfficerDashboardController.getRecentApplications';

import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

const USER_FIELDS = [NAME_FIELD];

export default class PfLoanOfficerDashboard extends NavigationMixin(
    LightningElement
) {
    userId = Id;
    userName = '';
    metrics = {
        totalApplications: 0,
        pendingReview: 0,
        approvedApplications: 0,
        rejectedApplications: 0,
        totalRequestedAmount: 0
    };

    applications = [];
    searchTerm = '';
    isLoading = true;
    errorMessage = '';

    wiredMetricsResult;
    wiredApplicationsResult;

    @wire(getRecord, { recordId: '$userId', fields: USER_FIELDS })
    wiredUser({ data }) {
        if (data) {
            this.userName = getFieldValue(data, NAME_FIELD) || '';
        }
    }

    @wire(getDashboardMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;

        if (result.data) {
            this.metrics = result.data;
            this.errorMessage = '';
        } else if (result.error) {
            this.errorMessage = this.getErrorMessage(result.error);
        }

        this.updateLoadingState();
    }

    @wire(getRecentApplications)
    wiredRecentApplications(result) {
        this.wiredApplicationsResult = result;

        if (result.data) {
            this.applications = result.data.map((record) => ({
                ...record,
                statusClass: this.getStatusClass(record.status)
            }));
            this.errorMessage = '';
        } else if (result.error) {
            this.errorMessage = this.getErrorMessage(result.error);
        }

        this.updateLoadingState();
    }

    get firstName() {
        return this.userName.split(' ')[0] || 'there';
    }

    get userInitials() {
        return this.userName
            .split(' ')
            .filter(Boolean)
            .slice(0, 2)
            .map((part) => part.charAt(0).toUpperCase())
            .join('') || 'PF';
    }

    get visibleApplications() {
        const term = this.searchTerm.trim().toLowerCase();

        if (!term) {
            return this.applications;
        }

        return this.applications.filter((record) =>
            [
                record.applicationNumber,
                record.customerName,
                record.segment,
                record.status
            ].some((value) => (value || '').toLowerCase().includes(term))
        );
    }

    get hasApplications() {
        return this.visibleApplications.length > 0;
    }

    updateLoadingState() {
        if (this.wiredMetricsResult && this.wiredApplicationsResult) {
            this.isLoading = false;
        }
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
    }

    async refreshDashboard() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            await Promise.all([
                refreshApex(this.wiredMetricsResult),
                refreshApex(this.wiredApplicationsResult)
            ]);
        } catch (error) {
            this.errorMessage = this.getErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    getStatusClass(status) {
        const normalized = (status || '').toLowerCase();

        if (normalized === 'approved') {
            return 'status-pill status-approved';
        }
        if (normalized === 'rejected') {
            return 'status-pill status-rejected';
        }
        if (normalized === 'under review' || normalized === 'submitted') {
            return 'status-pill status-pending';
        }
        if (normalized === 'withdrawn') {
            return 'status-pill status-muted';
        }

        return 'status-pill status-draft';
    }

    getErrorMessage(error) {
        const body = error?.body;

        if (Array.isArray(body)) {
            return body.map((item) => item.message).join(', ');
        }

        return body?.message || error?.message ||
            'Something went wrong while loading the dashboard.';
    }

    showDashboard() {
        // Already on the dashboard.
    }

    openApplications() {
        this.navigateToObject('Loan_Application__c');
    }

    openLoans() {
        this.navigateToObject('Loan__c');
    }

    openPayments() {
        this.navigateToObject('Loan_Payment__c');
    }

    openCustomers() {
        this.navigateToObject('Account');
    }

    navigateToObject(objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName,
                actionName: 'list'
            }
        });
    }
}
