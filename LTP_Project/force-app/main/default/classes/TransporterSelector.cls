public with sharing class TransporterSelector {

    /**
     * Récupère une Map de transporteurs par IDs pour les validations.
     */
    public static Map<Id, Transporteur__c> getTransportersMapById(Set<Id> transporterIds) {
        return new Map<Id, Transporteur__c>([
            SELECT Id, Name, Type_de_client__c 
            FROM Transporteur__c 
            WHERE Id IN :transporterIds
            WITH SECURITY_ENFORCED
        ]);
    }

    /**
     * Trouve les transporteurs éligibles triés par prix et délai.
     * Utilise le Child Relationship Name: Tarif_transporteurs__r
     */
    public static List<Transporteur__c> getBestCarriersWithDetails(String country, String clientType) {
        return [
            SELECT Id, Name, 
                   (SELECT Id, Prix__c, Delai_Livraison__c FROM Tarif_transporteurs__r 
                    WHERE Pays__c = :country 
                    ORDER BY Prix__c ASC, Delai_Livraison__c ASC)
            FROM Transporteur__c 
            WHERE Type_de_client__c INCLUDES (:clientType)
            AND Id IN (SELECT Transporteur__c FROM Tarif_transporteur__c WHERE Pays__c = :country)
            WITH SECURITY_ENFORCED
            LIMIT 10
        ];
    }
}