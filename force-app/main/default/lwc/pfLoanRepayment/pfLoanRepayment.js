import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import searchActiveLoans from '@salesforce/apex/LoanPaymentService.searchActiveLoans';
import recordPayment from '@salesforce/apex/LoanPaymentService.recordPayment';
import markPaymentSuccessful from '@salesforce/apex/LoanPaymentService.markPaymentSuccessful';
import reversePayment from '@salesforce/apex/LoanPaymentService.reversePayment';
import getLoanPayments from '@salesforce/apex/LoanPaymentService.getLoanPayments';
import getLoan from '@salesforce/apex/LoanService.getLoan';

const METHOD_OPTIONS = [
    { label: 'UPI / Digital Payment', value: 'UPI' },
    { label: 'Cash', value: 'Cash' },
    { label: 'Bank Transfer (NEFT/RTGS/IMPS)', value: 'Bank Transfer' },
    { label: 'Debit / Credit Card', value: 'Card' },
    { label: 'Cheque / Demand Draft', value: 'Cheque' },
    { label: 'Other', value: 'Other' }
];

const TYPE_OPTIONS = [
    { label: 'Regular Installment (EMI)', value: 'Regular Installment' },
    { label: 'Part Payment', value: 'Part Payment' },
    { label: 'Full Settlement', value: 'Full Settlement' },
    { label: 'Penalty / Charges', value: 'Penalty' },
    { label: 'Other', value: 'Other' }
];

export default class PfLoanRepayment extends LightningElement {
    @api recordId;

    isLoading = false;
    searchTerm = '';
    @track activeLoans = [];
    wiredLoansResult;

    @track selectedLoan = null;
    @track payments = [];

    // Form inputs
    paymentAmount = null;
    paymentDate = new Date().toISOString().slice(0, 10);
    paymentMethod = 'UPI';
    paymentType = 'Regular Installment';
    transactionReference = '';
    paymentNotes = '';

    methodOptions = METHOD_OPTIONS;
    typeOptions = TYPE_OPTIONS;

    // Reversal modal
    showReverseModal = false;
    selectedPaymentIdToReverse = null;
    selectedPaymentAmount = null;
    reversalReason = '';

    connectedCallback() {
        if (this.recordId) {
            this.loadSpecificLoan(this.recordId);
        }
    }

    @wire(searchActiveLoans, { searchTerm: '$searchTerm' })
    wiredLoans(result) {
        this.wiredLoansResult = result;
        if (result.data) {
            this.activeLoans = result.data;
        } else if (result.error) {
            this.activeLoans = [];
        }
    }

    get showLoanSelection() {
        return !this.selectedLoan;
    }

    get hasActiveLoans() {
        return this.activeLoans && this.activeLoans.length > 0;
    }

    get hasPayments() {
        return this.payments && this.payments.length > 0;
    }

    get todayDate() {
        return new Date().toISOString().slice(0, 10);
    }

    get loanStatusClass() {
        const s = this.selectedLoan?.Loan_Status__c;
        if (s === 'Active') return 'badge badge-active';
        if (s === 'Closed') return 'badge badge-closed';
        return 'badge badge-draft';
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value || '';
    }

    async loadSpecificLoan(loanId) {
        this.isLoading = true;
        try {
            const loan = await getLoan({ loanId });
            this.selectedLoan = loan;
            this.paymentAmount = loan.Monthly_Installment__c || loan.Outstanding_Balance__c;
            await this.loadLoanPayments(loan.Id);
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadLoanPayments(loanId) {
        try {
            const rawPayments = await getLoanPayments({ loanId });
            this.payments = rawPayments.map(p => ({
                ...p,
                isPending: p.Payment_Status__c === 'Pending',
                isSuccessful: p.Payment_Status__c === 'Successful',
                statusBadgeClass: this.computePaymentStatusClass(p.Payment_Status__c)
            }));
        } catch (error) {
            this.payments = [];
        }
    }

    computePaymentStatusClass(status) {
        if (status === 'Successful') return 'badge badge-approved';
        if (status === 'Pending') return 'badge badge-submitted';
        if (status === 'Reversed') return 'badge badge-rejected';
        return 'badge badge-draft';
    }

    handleSelectLoan(event) {
        const loanId = event.currentTarget.dataset.id;
        this.loadSpecificLoan(loanId);
    }

    handleClearSelection() {
        this.selectedLoan = null;
        this.payments = [];
        this.resetPaymentForm();
        if (this.wiredLoansResult) {
            refreshApex(this.wiredLoansResult);
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            if (this.selectedLoan) {
                await this.loadSpecificLoan(this.selectedLoan.Id);
            }
            if (this.wiredLoansResult) {
                await refreshApex(this.wiredLoansResult);
            }
            this.showToast('Refreshed', 'Loan and payment ledger refreshed.', 'info');
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSetEmiAmount() {
        if (this.selectedLoan) {
            this.paymentAmount = this.selectedLoan.Monthly_Installment__c;
            this.paymentType = 'Regular Installment';
        }
    }

    handleSetFullBalance() {
        if (this.selectedLoan) {
            this.paymentAmount = this.selectedLoan.Outstanding_Balance__c;
            this.paymentType = 'Full Settlement';
        }
    }

    handleAmountChange(event) {
        this.paymentAmount = parseFloat(event.target.value) || 0;
    }

    handleDateChange(event) {
        this.paymentDate = event.target.value;
    }

    handleMethodChange(event) {
        this.paymentMethod = event.detail.value;
    }

    handleTypeChange(event) {
        this.paymentType = event.detail.value;
    }

    handleReferenceChange(event) {
        this.transactionReference = event.target.value;
    }

    handleNotesChange(event) {
        this.paymentNotes = event.target.value;
    }

    validatePaymentInputs() {
        if (!this.paymentAmount || this.paymentAmount <= 0) {
            this.showToast('Validation Error', 'Payment amount must be greater than zero.', 'warning');
            return false;
        }
        if (this.paymentAmount > this.selectedLoan.Outstanding_Balance__c) {
            this.showToast(
                'Validation Error',
                `Payment amount cannot exceed outstanding balance of ₹${this.selectedLoan.Outstanding_Balance__c}.`,
                'warning'
            );
            return false;
        }
        if (!this.paymentDate || this.paymentDate > this.todayDate) {
            this.showToast('Validation Error', 'Payment date cannot be empty or in the future.', 'warning');
            return false;
        }
        if (!this.paymentMethod || !this.paymentType) {
            this.showToast('Validation Error', 'Please select both payment method and type.', 'warning');
            return false;
        }
        return true;
    }

    async handleRecordAndComplete() {
        if (!this.validatePaymentInputs()) return;

        this.isLoading = true;
        try {
            // 1. Record pending payment
            const paymentId = await recordPayment({
                loanId: this.selectedLoan.Id,
                amount: this.paymentAmount,
                paymentDate: this.paymentDate,
                paymentMethod: this.paymentMethod,
                paymentType: this.paymentType,
                transactionReference: this.transactionReference,
                paymentNotes: this.paymentNotes
            });

            // 2. Mark successful to reconcile ledger balance atomically
            await markPaymentSuccessful({ paymentId });

            this.showToast('Payment Successful', `Payment of ₹${this.paymentAmount} processed and reconciled!`, 'success');

            this.resetPaymentForm();
            await this.loadSpecificLoan(this.selectedLoan.Id);
            if (this.wiredLoansResult) {
                refreshApex(this.wiredLoansResult);
            }
        } catch (error) {
            this.showToast('Payment Processing Failed', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRecordPendingOnly() {
        if (!this.validatePaymentInputs()) return;

        this.isLoading = true;
        try {
            await recordPayment({
                loanId: this.selectedLoan.Id,
                amount: this.paymentAmount,
                paymentDate: this.paymentDate,
                paymentMethod: this.paymentMethod,
                paymentType: this.paymentType,
                transactionReference: this.transactionReference,
                paymentNotes: this.paymentNotes
            });

            this.showToast('Pending Payment Recorded', 'Payment recorded in Pending status.', 'info');
            this.resetPaymentForm();
            await this.loadLoanPayments(this.selectedLoan.Id);
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleMarkSuccessful(event) {
        const paymentId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await markPaymentSuccessful({ paymentId });
            this.showToast('Payment Confirmed', 'Payment marked Successful and loan balance updated.', 'success');
            await this.loadSpecificLoan(this.selectedLoan.Id);
            if (this.wiredLoansResult) {
                refreshApex(this.wiredLoansResult);
            }
        } catch (error) {
            this.showToast('Confirmation Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenReverseModal(event) {
        const paymentId = event.currentTarget.dataset.id;
        const target = this.payments.find(p => p.Id === paymentId);
        this.selectedPaymentIdToReverse = paymentId;
        this.selectedPaymentAmount = target?.Payment_Amount__c || 0;
        this.reversalReason = '';
        this.showReverseModal = true;
    }

    handleCloseReverseModal() {
        this.showReverseModal = false;
        this.selectedPaymentIdToReverse = null;
    }

    handleReversalReasonChange(event) {
        this.reversalReason = event.target.value;
    }

    async handleConfirmReverse() {
        if (!this.reversalReason || !this.reversalReason.trim()) {
            this.showToast('Required Field', 'Please provide a mandatory reversal reason.', 'warning');
            return;
        }

        this.isLoading = true;
        this.showReverseModal = false;
        try {
            await reversePayment({
                paymentId: this.selectedPaymentIdToReverse,
                reversalReason: this.reversalReason.trim()
            });

            this.showToast('Payment Reversed', 'Payment reversed and loan balance restored.', 'success');
            await this.loadSpecificLoan(this.selectedLoan.Id);
            if (this.wiredLoansResult) {
                refreshApex(this.wiredLoansResult);
            }
        } catch (error) {
            this.showToast('Reversal Failed', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetPaymentForm() {
        this.paymentAmount = this.selectedLoan?.Monthly_Installment__c || 0;
        this.paymentDate = this.todayDate;
        this.paymentMethod = 'UPI';
        this.paymentType = 'Regular Installment';
        this.transactionReference = '';
        this.paymentNotes = '';
    }

    extractErrorMessage(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred during payment servicing.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
