import { LightningElement, api, wire, track } from 'lwc';
import getShippingOptions from '@salesforce/apex/OrderService.getShippingOptions';
import confirmDelivery from '@salesforce/apex/OrderService.confirmDelivery';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';

// On importe le champ Status pour savoir si la commande est déjà activée
import STATUS_FIELD from '@salesforce/schema/Order.Status';

export default class OrderDeliveryManager extends LightningElement {
    @api recordId;
    @track cheapestOption;
    @track fastestOption;
    @track carrierOptions = [];
    @track isDelivered = false; // Gère l'affichage des templates HTML
    
    selectedCarrierId;
    wiredOptionsResult;

    // 1. Récupération du statut actuel de la commande
    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD] })
    wiredOrder({ error, data }) {
        if (data) {
            const status = data.fields.Status.value;
            this.isDelivered = (status === 'Activated');
        } else if (error) {
            console.error('Erreur lors de la récupération du statut', error);
        }
    }

    // 2. Récupération des options de transporteurs
    @wire(getShippingOptions, { orderId: '$recordId' })
    wiredOptions(result) {
        this.wiredOptionsResult = result;
        const { data, error } = result;

        if (data) {
            this.cheapestOption = data.cheapest;
            this.fastestOption = data.fastest;
            
            if (data.allOptions) {
                this.carrierOptions = data.allOptions.map(opt => {
                    return {
                        label: `${opt.Transporteur__r.Name} (${opt.Prix__c}€ - ${opt.Delai_Livraison__c}j)`,
                        value: opt.Transporteur__c
                    };
                });
            }
        } else if (error) {
            this.carrierOptions = [];
        }
    }

    handleCarrierChange(event) {
        this.selectedCarrierId = event.detail.value;
    }

    // 3. Confirmation de la livraison
    async handleConfirm() {
        if (!this.selectedCarrierId) {
            this.showToast('Erreur', 'Veuillez choisir un transporteur', 'error');
            return;
        }

        try {
            await confirmDelivery({ 
                orderId: this.recordId, 
                carrierId: this.selectedCarrierId 
            });

            this.showToast('Succès', 'Livraison lancée avec succès !', 'success');

            // Notifie Salesforce que le record a changé pour rafraîchir l'UI globale
            getRecordNotifyChange([{ recordId: this.recordId }]);
            
            // Rafraîchit les données du wire pour basculer l'affichage
            return refreshApex(this.wiredOptionsResult);

        } catch (error) {
            // --- NETTOYAGE DU MESSAGE D'ERREUR APEX ---
            let message = 'Une erreur inconnue est survenue';
            
            if (error.body && error.body.message) {
                message = error.body.message;
                
                // Si c'est une erreur de validation (addError dans le trigger)
                if (message.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION,')) {
                    // On ne garde que ce qui est après la virgule
                    message = message.split('FIELD_CUSTOM_VALIDATION_EXCEPTION,')[1];
                }
                
                // On nettoie les espaces et on enlève le ": []" final s'il existe
                message = message.replace(': []', '').trim();
            }

            this.showToast('Erreur', message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}