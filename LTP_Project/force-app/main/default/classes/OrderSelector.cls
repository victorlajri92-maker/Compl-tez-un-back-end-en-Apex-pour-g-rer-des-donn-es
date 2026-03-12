/**
 * @description Classe Selector pour centraliser les requêtes SOQL sur l'objet Order.
 * @author Vico, Développeur Salesforce
 * @date 2026-03-12
 */
public with sharing class OrderSelector {

    /**
     * @description Récupère les commandes avec leurs produits associés pour validation.
     * @param orderIds Set d'identifiants de commandes.
     * @return Liste de commandes incluant le type de compte et les OrderItems.
     */
    public static List<Order> getOrdersWithItems(Set<Id> orderIds) {
        return [
            SELECT Id, 
                   Account.Type_de_compte__c, 
                   (SELECT Id FROM OrderItems) 
            FROM Order 
            WHERE Id IN :orderIds 
            WITH SECURITY_ENFORCED
        ];
    }

    /**
     * @description Récupère les détails d'une commande spécifique pour le calcul des frais de port.
     * @param orderId ID de la commande.
     * @return L'objet Order avec les informations de compte et de pays.
     */
    public static Order getOrderForShipping(Id orderId) {
        return [
            SELECT Id, 
                   BillingCountry, 
                   Account.Type_de_compte__c 
            FROM Order 
            WHERE Id = :orderId 
            WITH SECURITY_ENFORCED 
            LIMIT 1
        ];
    }
}