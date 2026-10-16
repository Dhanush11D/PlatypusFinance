import { LightningElement, api, wire, track } from 'lwc';
import Id from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getApplication from '@salesforce/apex/LoanApplicationService.getApplication';
import getApplicationsForReview from '@salesforce/apex/LoanApplicationService.getApplicationsForReview';
import assessEligibility from '@salesforce/apex/LoanApplicationService.assessEligibility';
import assignManager from '@salesforce/apex/LoanApplicationService.assignManager';
import startReview from '@salesforce/apex/LoanApplicationService.startReview';
import approveApplication from '@salesforce/apex/LoanApplicationService.approveApplication';
import rejectApplication from '@salesforce/apex/LoanApplicationService.rejectApplication';
import withdrawApplication from '@salesforce/apex/LoanApplicationService.withdrawApplication';

const REJECTION_OPTIONS = [
    { label: 'Insufficient Income', value: 'Insufficient Income' },
    { label: 'Eligibility Criteria Not Met', value: 'Eligibility Criteria Not Met' },
    { label: 'Incomplete Documentation', value: 'Incomplete Documentation' },
    { label: 'High Risk', value: 'High Risk' },
    { label: 'Other', value: 'Other' }
];

const INTEREST_RATES = {
    Personal: 12.0,
    Business: 15.0,
    Emergency: 18.0,
    Education: 8.0
};

export default class PfLoanApplicationReview extends LightningElement {
    @api recordId;

    currentUserId = Id;
    isLoading = false;
    selectedRecordId = null;

    @track application = null;
    @track reviewQueue = [];
    wiredQueueResult;

    showRejectModal = false;
    selectedRejectionReason = '';
    decisionComments = '';

    rejectionReasonOptions = REJECTION_OPTIONS;

    connectedCallback() {
        if (this.recordId) {
            this.selectedRecordId = this.recordId;
            this.loadApplicationRecord();
        }
    }

    @wire(getApplicationsForReview)
    wiredQueue(result) {
        this.wiredQueueResult = result;
        if (result.data) {
            this.reviewQueue = result.data.map(item => ({
                ...item,
                managerName: item.Assigned_Manager__r?.Name || 'Unassigned',
                statusClass: this.computeBadgeClass(item.Application_Status__c),
                eligibilityClass: this.computeEligibilityClass(item.Eligibility_Status__c)
            }));
        } else if (result.error) {
            this.reviewQueue = [];
        }
    }

    get activeId() {
        return this.recordId || this.selectedRecordId;
    }

    get isRecordView() {
        return !this.recordId && !!this.selectedRecordId;
    }

    get showQueueView() {
        return !this.activeId;
    }

    get showDetailView() {
        return !!this.activeId && !!this.application;
    }

    get hasQueueItems() {
        return this.reviewQueue && this.reviewQueue.length > 0;
    }

    async loadApplicationRecord() {
        if (!this.activeId) return;

        this.isLoading = true;
        try {
            const data = await getApplication({ applicationId: this.activeId });
            this.application = data;
            this.decisionComments = data.Decision_Comments__c || '';
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectFromQueue(event) {
        this.selectedRecordId = event.currentTarget.dataset.id;
        this.loadApplicationRecord();
    }

    handleBackToQueue() {
        this.selectedRecordId = null;
        this.application = null;
        if (this.wiredQueueResult) {
            refreshApex(this.wiredQueueResult);
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            if (this.activeId) {
                await this.loadApplicationRecord();
            }
            if (this.wiredQueueResult) {
                await refreshApex(this.wiredQueueResult);
            }
            this.showToast('Refreshed', 'Latest loan application data retrieved.', 'info');
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Logic & Permissions
    get isAssignedToCurrentUser() {
        return this.application && this.application.Assigned_Manager__c === this.currentUserId;
    }

    get canAssignToMe() {
        if (!this.application) return false;
        const status = this.application.Application_Status__c;
        const canTakeAction = status === 'Submitted' || status === 'Under Review';
        return canTakeAction && !this.isAssignedToCurrentUser;
    }

    get isAssessDisabled() {
        if (!this.application) return true;
        const status = this.application.Application_Status__c;
        return status !== 'Submitted' && status !== 'Under Review';
    }

    get isStartReviewDisabled() {
        if (!this.application) return true;
        return (
            this.application.Application_Status__c !== 'Submitted' ||
            !this.isAssignedToCurrentUser
        );
    }

    get isDecisionDisabled() {
        if (!this.application) return true;
        return (
            this.application.Application_Status__c !== 'Under Review' ||
            !this.isAssignedToCurrentUser
        );
    }

    get isApproveDisabled() {
        if (this.isDecisionDisabled) return true;
        return this.application.Eligibility_Status__c !== 'Eligible';
    }

    get isRejectDisabled() {
        return this.isDecisionDisabled;
    }

    get canWithdraw() {
        if (!this.application) return false;
        const status = this.application.Application_Status__c;
        return status === 'Draft' || status === 'Submitted';
    }

    get isManualReview() {
        return this.application && this.application.Eligibility_Status__c === 'Manual Review';
    }

    get interestRate() {
        if (!this.application?.Loan_Segment__c) return 0;
        return INTEREST_RATES[this.application.Loan_Segment__c] || 0;
    }

    get incomeSnapshot() {
        return this.application?.Monthly_Income_Snapshot__c ||
               this.application?.Applicant_Contact__r?.Monthly_Income__c || 0;
    }

    get managerDisplay() {
        return this.application?.Assigned_Manager__r?.Name || 'Unassigned';
    }

    get formattedApplicationDate() {
        if (!this.application?.Application_Date__c) return '—';
        return this.application.Application_Date__c;
    }

    get formattedApprovedDate() {
        if (!this.application?.Approved_Date__c) return '—';
        return new Date(this.application.Approved_Date__c).toLocaleString();
    }

    get formattedRejectedDate() {
        if (!this.application?.Rejected_Date__c) return '—';
        return new Date(this.application.Rejected_Date__c).toLocaleString();
    }

    // Badge styling helpers
    computeBadgeClass(status) {
        const val = (status || '').toLowerCase();
        if (val === 'approved') return 'badge badge-approved';
        if (val === 'rejected') return 'badge badge-rejected';
        if (val === 'under review') return 'badge badge-review';
        if (val === 'submitted') return 'badge badge-submitted';
        if (val === 'withdrawn') return 'badge badge-withdrawn';
        return 'badge badge-draft';
    }

    computeEligibilityClass(status) {
        const val = (status || '').toLowerCase();
        if (val === 'eligible') return 'badge badge-eligible';
        if (val === 'ineligible') return 'badge badge-ineligible';
        if (val === 'manual review') return 'badge badge-manual';
        return 'badge badge-draft';
    }

    get statusBadgeClass() {
        return this.computeBadgeClass(this.application?.Application_Status__c);
    }

    get eligibilityBadgeClass() {
        return this.computeEligibilityClass(this.application?.Eligibility_Status__c);
    }

    get customerStatusClass() {
        const status = this.application?.Customer_Account__r?.Customer_Status__c;
        if (status === 'Active') return 'param-value font-bold text-success';
        return 'param-value font-bold text-danger';
    }

    get kycStatusClass() {
        const kyc = this.application?.Customer_Account__r?.KYC_Status__c;
        if (kyc === 'Verified') return 'param-value font-bold text-success';
        if (kyc === 'Pending') return 'param-value font-bold text-warning';
        return 'param-value font-bold text-danger';
    }

    get riskCategoryClass() {
        const risk = this.application?.Customer_Account__r?.Risk_Category__c;
        if (risk === 'Low') return 'param-value font-bold text-success';
        if (risk === 'Medium') return 'param-value font-bold text-warning';
        return 'param-value font-bold text-danger';
    }

    // Actions
    async handleAssignToMe() {
        this.isLoading = true;
        try {
            await assignManager({
                applicationId: this.activeId,
                managerUserId: this.currentUserId
            });
            this.showToast('Success', 'Application assigned to you successfully.', 'success');
            await this.loadApplicationRecord();
            if (this.wiredQueueResult) {
                refreshApex(this.wiredQueueResult);
            }
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleAssessEligibility() {
        this.isLoading = true;
        try {
            const outcome = await assessEligibility({ applicationId: this.activeId });
            this.showToast('Assessment Complete', `Eligibility status determined: ${outcome}`, 'success');
            await this.loadApplicationRecord();
        } catch (error) {
            this.showToast('Assessment Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleStartReview() {
        this.isLoading = true;
        try {
            await startReview({ applicationId: this.activeId });
            this.showToast('Review Started', 'Application is now Under Review.', 'success');
            await this.loadApplicationRecord();
            if (this.wiredQueueResult) {
                refreshApex(this.wiredQueueResult);
            }
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCommentsChange(event) {
        this.decisionComments = event.target.value;
    }

    handleReasonChange(event) {
        this.selectedRejectionReason = event.detail.value;
    }

    async handleApprove() {
        this.isLoading = true;
        try {
            await approveApplication({ applicationId: this.activeId });
            this.showToast('Application Approved', 'Loan application approved and marked Decision Complete.', 'success');
            await this.loadApplicationRecord();
            if (this.wiredQueueResult) {
                refreshApex(this.wiredQueueResult);
            }
        } catch (error) {
            this.showToast('Approval Failed', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenRejectModal() {
        this.selectedRejectionReason = '';
        this.showRejectModal = true;
    }

    handleCloseRejectModal() {
        this.showRejectModal = false;
    }

    async handleConfirmReject() {
        if (!this.selectedRejectionReason) {
            this.showToast('Required Field', 'Please select a valid regulatory rejection reason.', 'warning');
            return;
        }

        this.isLoading = true;
        this.showRejectModal = false;
        try {
            await rejectApplication({
                applicationId: this.activeId,
                rejectionReason: this.selectedRejectionReason,
                decisionComments: this.decisionComments
            });
            this.showToast('Application Rejected', 'Application has been formally rejected.', 'success');
            await this.loadApplicationRecord();
            if (this.wiredQueueResult) {
                refreshApex(this.wiredQueueResult);
            }
        } catch (error) {
            this.showToast('Rejection Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleWithdraw() {
        this.isLoading = true;
        try {
            await withdrawApplication({ applicationId: this.activeId });
            this.showToast('Application Withdrawn', 'The application has been withdrawn.', 'info');
            await this.loadApplicationRecord();
            if (this.wiredQueueResult) {
                refreshApex(this.wiredQueueResult);
            }
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    extractErrorMessage(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
