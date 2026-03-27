/**
 * Trigger sur l'objet Order (Commande)
 * Gère la validation des données avant l'enregistrement en base.
 */
trigger OrderTrigger on Order (before insert, before update) {
    
    // On utilise le contexte "Before" pour bloquer l'enregistrement si une erreur est trouvée
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        
    
        List<Order> ordersToValidateProducts = new List<Order>();
        for (Order newOrd : Trigger.new) {
            // Règle : On ne valide le nombre de produits QUE si la commande passe à 'Activated'
            if (newOrd.Status == 'Activated' && (Trigger.isInsert || Trigger.oldMap.get(newOrd.Id).Status != 'Activated')) {
                ordersToValidateProducts.add(newOrd);
            }
        }

        if (!ordersToValidateProducts.isEmpty()) {
            // Règle 1 : Vérification du nombre de produits (3 ou 5) UNIQUEMENT lors de l'activation
            OrderService.validateOrderProducts(ordersToValidateProducts);
        }
        
        // --- AUTRES VALIDATIONS (Qui peuvent s'exécuter à chaque mise à jour) ---
        // Règle 2 : Vérification de la compatibilité Type de Compte / Transporteur
        // On garde Trigger.new ici car cette validation peut être faite en continu
        OrderService.validateCarrierType(Trigger.new);
    }
}