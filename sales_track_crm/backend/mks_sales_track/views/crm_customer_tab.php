<?php

defined('BASEPATH') or exit('No direct script access allowed');

/**
 * MKS Sales Track - the Calls tab on a customer profile. Perfex loads this
 * view inside the customer page with $client set.
 */
$mks_numbers = [];
$mks_client  = isset($client) ? $client : null;

if ($mks_client) {
    $mks_ci = &get_instance();

    foreach ($mks_ci->db->select('firstname, lastname, phonenumber')->where('userid', (int) $mks_client->userid)->where('active', 1)
        ->where('phonenumber !=', '')->get(db_prefix() . 'contacts')->result_array() as $mks_contact) {
        $mks_numbers[] = ['number' => $mks_contact['phonenumber'], 'name' => trim($mks_contact['firstname'] . ' ' . $mks_contact['lastname'])];
    }

    if ((string) $mks_client->phonenumber !== '') {
        $mks_numbers[] = ['number' => $mks_client->phonenumber, 'name' => $mks_client->company];
    }
}
?>
<h4 class="customer-profile-group-heading"><?= e(_l('mks_st_tab_calls')); ?></h4>
<?php if ($mks_client) {
    $this->load->view(MKS_SALES_TRACK_MODULE_NAME . '/partials/crm_calls', [
        'mks_rel'     => 'customer',
        'mks_rel_id'  => (int) $mks_client->userid,
        'mks_numbers' => array_slice($mks_numbers, 0, 4),
    ]);
} ?>
