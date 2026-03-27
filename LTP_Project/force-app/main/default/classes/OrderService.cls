/**
 * @description Classe de service gérant la logique métier des Commandes et des Livraisons.
 * Centralise les validations et les calculs pour éviter la duplication dans les triggers ou LWC.
 */
public with sharing class OrderService {

    /**
     * REGLE METIER : Valide le nombre minimum de produits.
     * Empêche l'activation si : Particulier < 3 produits OU Professionnel < 5 produits.
     */
    public static void validateOrderProducts(List<Order> orders) {
        Set<Id> orderIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        
        // 1. Collecte des IDs pour limiter les requêtes SOQL
        for (Order ord : orders) {
            if (ord.Id != null) orderIds.add(ord.Id);
            if (ord.AccountId != null) accountIds.add(ord.AccountId);
        }

        // 2. Récupération des données liées (Comptes et Produits) via les Selectors
        Map<Id, Account> accountMap = AccountSelector.getAccountsById(accountIds);
        List<Order> ordersWithItems = OrderSelector.getOrdersWithItems(orderIds);
        
        // 3. Mapping du nombre de produits par commande
        Map<Id, Integer> orderToItemCount = new Map<Id, Integer>();
        for (Order owi : ordersWithItems) {
            orderToItemCount.put(owi.Id, owi.OrderItems.size());
        }

        // 4. Boucle de validation finale
        for (Order ord : orders) {
            Integer itemCount = orderToItemCount.containsKey(ord.Id) ? orderToItemCount.get(ord.Id) : 0;
            Account acc = accountMap.get(ord.AccountId);
            String accountType = (acc != null && acc.RecordType != null) ? acc.RecordType.DeveloperName : null;

            // Application des messages d'erreur bloquants sur l'UI
            if (accountType == 'Particulier' && itemCount < 3) {
                ord.addError('Panier insuffisant : 3 produits minimum requis pour un Particulier.');
            } else if (accountType == 'Professionnel' && itemCount < 5) {
                ord.addError('Commande pro : 5 produits minimum requis pour un Professionnel.');
            }
        }
    }

    /**
     * UTILITAIRE TRIGGER : Point d'entrée pour valider le transporteur lors d'un changement sur la Commande.
     */
    public static void validateCarrierType(List<Order> orders) {
        // Relance le calcul du transporteur pour s'assurer qu'il est toujours compatible
        autoSelectCarrier(orders);
    }

    /**
     * AUTOMATISATION : Sélectionne et SAUVEGARDE le meilleur transporteur.
     * Utilisé par le Trigger OrderItem quand on ajoute/supprime des produits.
     */
    public static void autoSelectBestCarrier(List<OrderItem> items) {
        Set<Id> orderIds = new Set<Id>();
        for (OrderItem item : items) { orderIds.add(item.OrderId); }
        
        // Récupère les commandes impactées avec les infos de destination
        List<Order> ordersToProcess = [
            SELECT Id, BillingCountry, Account.RecordType.DeveloperName 
            FROM Order 
            WHERE Id IN :orderIds
        ];
        
        // Calcule et met à jour en base de données
        autoSelectCarrier(ordersToProcess);
        update ordersToProcess;
    }

    /**
     * MOTEUR DE CALCUL : Identifie le transporteur le moins cher sans sauvegarder en base.
     * Modifie uniquement l'instance de l'objet en mémoire.
     */
    public static void autoSelectCarrier(List<Order> orders) {
        for (Order ord : orders) {
            if (ord.BillingCountry != null && ord.Account != null && ord.Account.RecordType != null) {
                // Demande au Selector les tarifs triés par prix croissant
                List<Tarif_transporteur__c> options = TransporterSelector.getAvailableTariffs(
                    ord.BillingCountry, 
                    ord.Account.RecordType.DeveloperName
                );
                
                // Prend l'option [0] (la moins chère grâce au tri SOQL)
                if (!options.isEmpty()) {
                    ord.Transporteur__c = options[0].Transporteur__c;
                }
            }
        }
    }

/**
     * LWC : Fournit les options de livraison au composant Lightning.
     * Calcule dynamiquement l'option la moins chère et la plus rapide pour l'affichage.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getShippingOptions(Id orderId) {
        // 1. Initialisation du dictionnaire (Map) qui sera renvoyé au composant LWC
        Map<String, Object> result = new Map<String, Object>();

        // 2. Récupération des données de la commande (Pays + Type de Compte) via le Selector
        Order ord = OrderSelector.getOrderForShipping(orderId);
        
        // Sécurité : Si la commande n'existe pas ou n'a pas de RecordType, on s'arrête pour éviter un crash
        if (ord == null || ord.Account.RecordType == null) return result;

        // 3. Appel au TransporterSelector : On récupère tous les tarifs qui matchent avec le Pays et le Profil (Pro/Perso)
        // Note : La liste est déjà triée par PRIX croissant grâce au "ORDER BY Prix__c" dans le Selector
        List<Tarif_transporteur__c> availableTariffs = TransporterSelector.getAvailableTariffs(
            ord.BillingCountry, 
            ord.Account.RecordType.DeveloperName
        );

        // Sécurité : Si aucun transporteur n'est trouvé pour cette destination, on renvoie une map vide
        if (availableTariffs.isEmpty()) return result;

        // 4. ANALYSE DES OPTIONS (Recherche du moins cher et du plus rapide)
        
        // Par défaut, on initialise "cheapest" et "fastest" avec le premier élément de la liste
        Tarif_transporteur__c cheapest = availableTariffs[0]; // Comme c'est trié par prix, le 1er est forcément le moins cher
        Tarif_transporteur__c fastest = availableTariffs[0]; 
        
        // On parcourt toute la liste pour comparer les délais de livraison
        for (Tarif_transporteur__c t : availableTariffs) {
            // Si le délai de ce transporteur (ex: 1j) est plus petit que celui enregistré (ex: 3j)
            if (t.Delai_Livraison__c < fastest.Delai_Livraison__c) {
                // Alors ce transporteur devient notre nouvelle option "la plus rapide"
                fastest = t;
            }
        }

        // 5. REMPLISSAGE DU RÉSULTAT
        // On range les données dans la Map avec des étiquettes (clés) que le LWC pourra lire
        result.put('cheapest', cheapest);     // Utilisé pour le badge "💰 Moins cher"
        result.put('fastest', fastest);       // Utilisé pour le badge "⚡ Plus rapide"
        result.put('allOptions', availableTariffs); // Utilisé pour remplir la liste déroulante (Combobox)
        
        // On renvoie le tout au JavaScript
        return result;
    }

    /**
     * LWC : Action finale déclenchée par le bouton de confirmation.
     * Met à jour le transporteur choisi, active la commande et définit la date.
     */
    @AuraEnabled
    public static void confirmDelivery(Id orderId, Id carrierId) {
        try {
            update new Order(
                Id = orderId, 
                Transporteur__c = carrierId, 
                Status = 'Activated', 
                EffectiveDate = Date.today()
            );
        } catch (Exception e) {
            // Renvoie une erreur propre au composant LWC
            throw new AuraHandledException('Erreur lors de la confirmation : ' + e.getMessage());
        }
    }
}