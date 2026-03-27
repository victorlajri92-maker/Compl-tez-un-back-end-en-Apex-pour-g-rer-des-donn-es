/**
 * @description Sélecteur pour l'objet Order (Commande).
 * Récupère les données nécessaires à la logique de livraison et au LWC.
 */
public with sharing class OrderSelector {

    /**
     * @description Récupère les détails d'une commande spécifique pour le composant de livraison.
     * @param orderId ID de la commande
     * @return Order avec les relations Account et RecordType
     */
    public static Order getOrderForShipping(Id orderId) {
        if (orderId == null) return null;

        return [
            SELECT Id, 
                   OrderNumber, 
                   BillingCountry, 
                   Status,
                   AccountId,
                   Account.Name,
                   Account.RecordType.DeveloperName // Champ indispensable pour le filtrage LWC
            FROM Order 
            WHERE Id = :orderId 
            LIMIT 1
        ];
    }

    /**
     * @description Récupère les commandes avec leurs produits (OrderItems).
     * Utilisé pour la validation du nombre de produits (3 ou 5).
     */
    public static List<Order> getOrdersWithItems(Set<Id> orderIds) {
        return [
            SELECT Id, 
                   (SELECT Id FROM OrderItems) 
            FROM Order 
            WHERE Id IN :orderIds
        ];
    }
}