/**
 * @description Classe de service gérant la logique métier des Commandes et des Livraisons.
 * @author Vico, Développeur Salesforce
 * @date 2026-03-12
 */
public with sharing class OrderService {

    /**
     * @description Valide le nombre minimum de produits (Appelée par OrderTrigger).
     */
    public static void validateOrderProducts(List<Order> orders) {
        Set<Id> orderIds = new Set<Id>();
        for (Order ord : orders) {
            if (ord.Id != null) orderIds.add(ord.Id);
        }

        List<Order> ordersWithItems = OrderSelector.getOrdersWithItems(orderIds);
        Map<Id, Integer> orderToItemCount = new Map<Id, Integer>();
        for (Order owi : ordersWithItems) {
            orderToItemCount.put(owi.Id, owi.OrderItems.size());
        }

        for (Order ord : orders) {
            Integer itemCount = orderToItemCount.containsKey(ord.Id) ? orderToItemCount.get(ord.Id) : 0;
            String accountType = ord.Account.Type_de_compte__c;

            if (accountType == 'Particulier' && itemCount < 3) {
                ord.addError('Une commande pour un particulier doit contenir au moins 3 produits.');
            } else if (accountType == 'Professionnel' && itemCount < 5) {
                ord.addError('Une commande pour un professionnel doit contenir au moins 5 produits.');
            }
        }
    }

    /**
     * @description Méthode demandée par OrderTrigger pour valider le transporteur.
     */
    public static void validateCarrierType(List<Order> orders) {
        autoSelectCarrier(orders);
    }

    /**
     * @description NOUVELLE MÉTHODE demandée par OrderItemTrigger (Capture d'écran).
     * @param items Liste des produits de commande ajoutés.
     */
    public static void autoSelectBestCarrier(List<OrderItem> items) {
        Set<Id> orderIds = new Set<Id>();
        for (OrderItem item : items) {
            orderIds.add(item.OrderId);
        }
        
        // On récupère les commandes parentes pour avoir le Pays et le Type de compte
        List<Order> ordersToProcess = [SELECT Id, BillingCountry, Account.Type_de_compte__c FROM Order WHERE Id IN :orderIds];
        autoSelectCarrier(ordersToProcess);
        update ordersToProcess;
    }

    /**
     * @description Logique de sélection automatique du transporteur le moins cher.
     */
    public static void autoSelectCarrier(List<Order> orders) {
        for (Order ord : orders) {
            if (ord.BillingCountry != null && ord.Account != null && ord.Account.Type_de_compte__c != null) {
                List<Tarif_transporteur__c> options = TransporterSelector.getAvailableTariffs(
                    ord.BillingCountry, 
                    ord.Account.Type_de_compte__c
                );
                if (!options.isEmpty()) {
                    ord.Transporteur__c = options[0].Transporteur__c;
                }
            }
        }
    }

    /**
     * @description Récupère les options de livraison pour le composant LWC.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getShippingOptions(Id orderId) {
        Map<String, Object> result = new Map<String, Object>();
        Order ord = OrderSelector.getOrderForShipping(orderId);
        List<Tarif_transporteur__c> availableTariffs = TransporterSelector.getAvailableTariffs(
            ord.BillingCountry, 
            ord.Account.Type_de_compte__c
        );

        if (availableTariffs.isEmpty()) return result;

        Tarif_transporteur__c cheapest = availableTariffs[0]; 
        Tarif_transporteur__c fastest = availableTariffs[0];
        for (Tarif_transporteur__c t : availableTariffs) {
            if (t.Delai_Livraison__c < fastest.Delai_Livraison__c) fastest = t;
        }

        result.put('cheapest', cheapest);
        result.put('fastest', fastest);
        result.put('allOptions', availableTariffs);
        return result;
    }

    /**
     * @description Finalise la livraison via le LWC.
     */
    @AuraEnabled
    public static void confirmDelivery(Id orderId, Id carrierId) {
        try {
            update new Order(Id = orderId, Transporteur__c = carrierId, Status = 'Activated', EffectiveDate = Date.today());
        } catch (Exception e) {
            throw new AuraHandledException('Erreur : ' + e.getMessage());
        }
    }
}