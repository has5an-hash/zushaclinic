<?php
$path = '/usr/src/wordpress/wp-content/plugins/zosha-suite/zosha-suite.php';
$code = file_get_contents($path);
if ($code === false) {
    fwrite(STDERR, "Cannot read Zosha Suite plugin\n");
    exit(1);
}

$marker = "define('ZOSHA_SUITE_URL', plugin_dir_url(__FILE__));\n";
$helper = <<<'PHP'

if (!function_exists('zosha_post_exists_by_title')) {
    function zosha_post_exists_by_title($title, $post_type = 'page') {
        global $wpdb;
        $id = $wpdb->get_var($wpdb->prepare(
            "SELECT ID FROM {$wpdb->posts} WHERE post_title = %s AND post_type = %s LIMIT 1",
            $title,
            $post_type
        ));
        return !empty($id);
    }
}
PHP;

if (strpos($code, 'function zosha_post_exists_by_title') === false) {
    $code = str_replace($marker, $marker . $helper . "\n", $code);
}

$replacements = [
    "get_page_by_title(\$service[0], OBJECT, 'zosha_service')" => "zosha_post_exists_by_title(\$service[0], 'zosha_service')",
    "get_page_by_title(\$item[0], OBJECT, 'zosha_portfolio')" => "zosha_post_exists_by_title(\$item[0], 'zosha_portfolio')",
    "get_page_by_title(\$post[0], OBJECT, 'post')" => "zosha_post_exists_by_title(\$post[0], 'post')",
    "get_page_by_title(\$title, OBJECT, 'page')" => "zosha_post_exists_by_title(\$title, 'page')",
];

$code = strtr($code, $replacements);
file_put_contents($path, $code);
