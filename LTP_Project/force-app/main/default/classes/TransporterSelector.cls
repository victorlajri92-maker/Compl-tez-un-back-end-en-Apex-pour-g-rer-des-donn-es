/**
 * @description Classe Selector pour centraliser les requêtes SOQL sur les Transporteurs et Tarifs.
 * @author Vico, Développeur Salesforce
 * @date 2026-03-12
 */
public with sharing class TransporterSelector {

    public static List<Tarif_transporteur__c> getAvailableTariffs(String country, String accountType) {
        return [
            SELECT Id, 
                   Transporteur__c, 
                   Transporteur__r.Name, 
                   Prix__c, 
                   Delai_Livraison__c 
            FROM Tarif_transporteur__c 
            WHERE Pays__c = :country 
            AND Type_de_compte__c = :accountType 
            WITH SECURITY_ENFORCED 
            ORDER BY Prix__c ASC
        ];
    }
}