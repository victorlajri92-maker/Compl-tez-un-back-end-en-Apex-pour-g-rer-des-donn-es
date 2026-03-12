/**
 * Trigger sur l'objet Order (Commande)
 * Gère la validation des données avant l'enregistrement en base.
 */
trigger OrderTrigger on Order (before insert, before update) {
    
    // On utilise le contexte "Before" pour bloquer l'enregistrement si une erreur est trouvée
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            // Règle 1 : Vérification du nombre de produits (3 ou 5)
            OrderService.validateOrderProducts(Trigger.new);
            
            // Règle 2 : Vérification de la compatibilité Type de Compte / Transporteur
            OrderService.validateCarrierType(Trigger.new);
        }
    }
}