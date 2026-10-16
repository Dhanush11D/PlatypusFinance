import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

import getApprovedApplications from '@salesforce/apex/LoanService.getApprovedApplications';
import disburseApprovedApplication from '@salesforce/apex/LoanService.disburseApprovedApplication';
import getLoan from '@salesforce/apex/LoanService.getLoan';

const INTEREST_RATES = {
    Personal: 12.0,
    Business: 15.0,
    Emergency: 18.0,
    Education: 8.0
};

export default class PfLoanDisbursement extends NavigationMixin(LightningElement) {
    isLoading = false;
    @track approvedApplications = [];
    wiredApprovedResult;

    selectedApplication = null;
    disbursementDate = new Date().toISOString().slice(0, 10);
    createdLoan = null;

    @wire(getApprovedApplications)
    wiredApproved(result) {
        this.wiredApprovedResult = result;
        if (result.data) {
            this.approvedApplications = result.data.map(app => ({
                ...app,
                approverName: app.Approved_By__r?.Name || 'Manager'
            }));
        } else if (result.error) {
            this.approvedApplications = [];
        }
    }

    get showListView() {
        return !this.selectedApplication && !this.createdLoan;
    }

    get showDisbursementForm() {
        return !!this.selectedApplication && !this.createdLoan;
    }

    get hasApprovedApplications() {
        return this.approvedApplications && this.approvedApplications.length > 0;
    }

    get todayDate() {
        return new Date().toISOString().slice(0, 10);
    }

    get interestRate() {
        if (!this.selectedApplication?.Loan_Segment__c) return 0;
        return INTEREST_RATES[this.selectedApplication.Loan_Segment__c] || 0;
    }

    get estimatedInstallment() {
        if (!this.selectedApplication) return 0;
        const principal = this.selectedApplication.Requested_Amount__c || 0;
        const rate = this.interestRate;
        const tenure = this.selectedApplication.Requested_Tenure_Months__c || 0;

        if (principal <= 0 || tenure <= 0) return 0;
        const monthlyRate = rate / 1200;
        if (monthlyRate === 0) return principal / tenure;

        const factor = Math.pow(1 + monthlyRate, tenure);
        return (principal * monthlyRate * factor) / (factor - 1);
    }

    handleSelectApplication(event) {
        const appId = event.currentTarget.dataset.id;
        this.selectedApplication = this.approvedApplications.find(a => a.Id === appId) || null;
        this.disbursementDate = this.todayDate;
        this.createdLoan = null;
    }

    handleBackToApprovedList() {
        this.selectedApplication = null;
        this.createdLoan = null;
        if (this.wiredApprovedResult) {
            refreshApex(this.wiredApprovedResult);
        }
    }

    handleDateChange(event) {
        this.disbursementDate = event.target.value;
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            if (this.wiredApprovedResult) {
                await refreshApex(this.wiredApprovedResult);
            }
            this.showToast('Refreshed', 'Approved applications list refreshed.', 'info');
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleExecuteDisbursement() {
        if (!this.disbursementDate) {
            this.showToast('Validation Error', 'Please specify a valid disbursement date.', 'warning');
            return;
        }

        if (this.disbursementDate > this.todayDate) {
            this.showToast('Validation Error', 'Disbursement date cannot be in the future.', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            const loanId = await disburseApprovedApplication({
                applicationId: this.selectedApplication.Id,
                actualDisbursementDate: this.disbursementDate
            });

            // Fetch newly created loan details
            const loanRecord = await getLoan({ loanId });
            this.createdLoan = loanRecord;
            this.selectedApplication = null;

            this.showToast('Success', `Loan ${loanRecord.Name} disbursed successfully!`, 'success');

            if (this.wiredApprovedResult) {
                refreshApex(this.wiredApprovedResult);
            }
        } catch (error) {
            this.showToast('Disbursement Failed', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleNavigateToLoan() {
        if (!this.createdLoan?.Id) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.createdLoan.Id,
                objectApiName: 'Loan__c',
                actionName: 'view'
            }
        });
    }

    handleDone() {
        this.createdLoan = null;
        this.selectedApplication = null;
        if (this.wiredApprovedResult) {
            refreshApex(this.wiredApprovedResult);
        }
    }

    extractErrorMessage(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred during disbursement.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
