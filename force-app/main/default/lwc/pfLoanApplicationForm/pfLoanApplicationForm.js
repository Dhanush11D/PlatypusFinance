import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { createRecord } from 'lightning/uiRecordApi';

import submitApplication from '@salesforce/apex/LoanApplicationService.submitApplication';

import LOAN_APPLICATION_OBJECT from '@salesforce/schema/Loan_Application__c';
import CUSTOMER_ACCOUNT_FIELD from '@salesforce/schema/Loan_Application__c.Customer_Account__c';
import APPLICANT_CONTACT_FIELD from '@salesforce/schema/Loan_Application__c.Applicant_Contact__c';
import APPLICATION_DATE_FIELD from '@salesforce/schema/Loan_Application__c.Application_Date__c';
import LOAN_SEGMENT_FIELD from '@salesforce/schema/Loan_Application__c.Loan_Segment__c';
import REQUESTED_AMOUNT_FIELD from '@salesforce/schema/Loan_Application__c.Requested_Amount__c';
import REQUESTED_TENURE_FIELD from '@salesforce/schema/Loan_Application__c.Requested_Tenure_Months__c';
import PURPOSE_FIELD from '@salesforce/schema/Loan_Application__c.Purpose_of_Loan__c';
import APPLICATION_STATUS_FIELD from '@salesforce/schema/Loan_Application__c.Application_Status__c';
import APPROVAL_STAGE_FIELD from '@salesforce/schema/Loan_Application__c.Approval_Stage__c';
import ELIGIBILITY_STATUS_FIELD from '@salesforce/schema/Loan_Application__c.Eligibility_Status__c';

export default class PfLoanApplicationForm extends NavigationMixin(LightningElement) {
    @track accountId = null;
    @track contactId = null;
    @track loanSegment = '';
    @track amount = null;
    @track tenure = null;
    @track purpose = '';
    @track isSubmitting = false;

    segmentOptions = [
        { label: 'Personal (12% p.a.)', value: 'Personal' },
        { label: 'Business (15% p.a.)', value: 'Business' },
        { label: 'Emergency (18% p.a.)', value: 'Emergency' },
        { label: 'Education (8% p.a.)', value: 'Education' }
    ];

    purposeOptions = [
        { label: 'Medical', value: 'Medical' },
        { label: 'Education', value: 'Education' },
        { label: 'Home Improvement', value: 'Home Improvement' },
        { label: 'Business Expansion', value: 'Business Expansion' },
        { label: 'Personal Expenses', value: 'Personal Expenses' },
        { label: 'Other', value: 'Other' }
    ];

    get contactFilter() {
        if (!this.accountId) {
            return null;
        }
        return {
            filterLogic: '1',
            criteria: [
                {
                    fieldPath: 'AccountId',
                    operator: 'eq',
                    value: this.accountId
                }
            ]
        };
    }

    handleAccountChange(event) {
        this.accountId = event.detail.recordId;
        this.contactId = null;
    }

    handleContactChange(event) {
        this.contactId = event.detail.recordId;
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        if (name === 'segment') {
            this.loanSegment = value;
        } else if (name === 'amount') {
            this.amount = value;
        } else if (name === 'tenure') {
            this.tenure = value;
        } else if (name === 'purpose') {
            this.purpose = value;
        }
    }

    handleReset() {
        this.accountId = null;
        this.contactId = null;
        this.loanSegment = '';
        this.amount = null;
        this.tenure = null;
        this.purpose = '';

        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox');
        if (inputs) {
            inputs.forEach(input => {
                input.value = null;
            });
        }
    }

    async handleSubmit() {
        if (this.isSubmitting) {
            return;
        }

        if (!this.accountId) {
            this.showToast('Validation Error', 'Please select a Customer Account.', 'error');
            return;
        }

        if (!this.contactId) {
            this.showToast('Validation Error', 'Please select an Applicant Contact associated with the Customer Account.', 'error');
            return;
        }

        const inputElements = [...this.template.querySelectorAll('lightning-input, lightning-combobox')];
        const allValid = inputElements.reduce((validSoFar, input) => {
            input.reportValidity();
            return validSoFar && input.checkValidity();
        }, true);

        if (!allValid) {
            this.showToast('Validation Error', 'Please complete all required fields correctly.', 'error');
            return;
        }

        const numAmount = parseFloat(this.amount);
        if (isNaN(numAmount) || numAmount < 10000 || numAmount > 500000) {
            this.showToast('Validation Error', 'Requested loan amount must be between ₹10,000 and ₹5,00,000.', 'error');
            return;
        }

        const numTenure = parseFloat(this.tenure);
        if (isNaN(numTenure) || numTenure < 3 || numTenure > 53 || !Number.isInteger(numTenure)) {
            this.showToast('Validation Error', 'Requested tenure must be a whole number between 3 and 53 months.', 'error');
            return;
        }

        this.isSubmitting = true;

        try {
            const todayStr = new Date().toISOString().slice(0, 10);

            const fields = {};
            fields[CUSTOMER_ACCOUNT_FIELD.fieldApiName] = this.accountId;
            fields[APPLICANT_CONTACT_FIELD.fieldApiName] = this.contactId;
            fields[APPLICATION_DATE_FIELD.fieldApiName] = todayStr;
            fields[LOAN_SEGMENT_FIELD.fieldApiName] = this.loanSegment;
            fields[REQUESTED_AMOUNT_FIELD.fieldApiName] = numAmount;
            fields[REQUESTED_TENURE_FIELD.fieldApiName] = numTenure;
            fields[PURPOSE_FIELD.fieldApiName] = this.purpose;
            fields[APPLICATION_STATUS_FIELD.fieldApiName] = 'Draft';
            fields[APPROVAL_STAGE_FIELD.fieldApiName] = 'Not Started';
            fields[ELIGIBILITY_STATUS_FIELD.fieldApiName] = 'Not Checked';

            const recordInput = {
                apiName: LOAN_APPLICATION_OBJECT.objectApiName,
                fields: fields
            };

            const createdApp = await createRecord(recordInput);

            await submitApplication({ applicationId: createdApp.id });

            this.showToast(
                'Application Submitted',
                'Loan application has been created and submitted successfully for Manager review.',
                'success'
            );

            const createdId = createdApp.id;
            this.handleReset();

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: createdId,
                    objectApiName: 'Loan_Application__c',
                    actionName: 'view'
                }
            });

        } catch (error) {
            const errorMsg = this.extractErrorMessage(error);
            this.showToast('Submission Failed', errorMsg, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    extractErrorMessage(error) {
        if (!error) {
            return 'An unknown error occurred.';
        }
        if (error.body) {
            if (error.body.message) {
                return error.body.message;
            }
            if (Array.isArray(error.body.pageErrors) && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
            if (error.body.output && error.body.output.errors && error.body.output.errors.length > 0) {
                return error.body.output.errors[0].message;
            }
            if (error.body.fieldErrors) {
                const firstField = Object.keys(error.body.fieldErrors)[0];
                if (firstField && error.body.fieldErrors[firstField].length > 0) {
                    return error.body.fieldErrors[firstField][0].message;
                }
            }
        }
        if (error.message) {
            return error.message;
        }
        return JSON.stringify(error);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        }));
    }
}