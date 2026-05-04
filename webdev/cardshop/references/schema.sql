-- 卡网商城数据库初始化脚本
-- 运行: mysql -u root -p < schema.sql

CREATE DATABASE IF NOT EXISTS cardshop DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE cardshop;

-- 商品表
CREATE TABLE IF NOT EXISTS goods (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL COMMENT '商品名称',
    `desc` TEXT COMMENT '商品描述',
    price DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT '价格',
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品表';

-- 卡密表
CREATE TABLE IF NOT EXISTS cards (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    good_id INT UNSIGNED NOT NULL COMMENT '关联商品ID',
    card_no VARCHAR(100) NOT NULL COMMENT '卡号',
    password VARCHAR(100) NOT NULL COMMENT '卡密',
    sold TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否已售',
    order_no VARCHAR(50) DEFAULT NULL COMMENT '关联订单号',
    sold_at DATETIME DEFAULT NULL COMMENT '售出时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE INDEX idx_card_no (card_no),
    INDEX idx_good_sold (good_id, sold)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='卡密表';

-- 订单表
CREATE TABLE IF NOT EXISTS orders (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_no VARCHAR(50) NOT NULL COMMENT '商户订单号',
    good_id INT UNSIGNED NOT NULL COMMENT '商品ID',
    good_name VARCHAR(200) NOT NULL COMMENT '冗余商品名称',
    amount DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT '支付金额',
    status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT 'pending/paid/paid_nocard',
    pay_type VARCHAR(20) DEFAULT NULL COMMENT '支付方式',
    trade_no VARCHAR(100) DEFAULT NULL COMMENT '平台订单号',
    card_no VARCHAR(100) DEFAULT NULL COMMENT '发货卡号',
    card_pwd VARCHAR(100) DEFAULT NULL COMMENT '发货卡密',
    expired_at DATETIME NOT NULL COMMENT '订单过期时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE INDEX idx_order_no (order_no),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

-- 管理员表
CREATE TABLE IF NOT EXISTS admins (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '用户名',
    password VARCHAR(255) NOT NULL COMMENT '密码（bcrypt）',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员表';

-- 初始化管理员 (密码: admin123)
INSERT INTO admins (username, password) VALUES
('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');

-- 初始化商品
INSERT INTO goods (name, `desc`, price) VALUES
('日卡', '开通日卡会员，畅享全部功能', 9.90),
('月卡', '开通月卡会员，畅享全部功能', 29.90),
('永久卡', '开通永久会员，畅享全部功能', 99.00);

-- 批量生成测试卡密（每个商品3张）
INSERT INTO cards (good_id, card_no, password) VALUES
(1,'D01001','A1B2C3D4E5F6'),(1,'D01002','F6E5D4C3B2A1'),(1,'D01003','123456789ABC'),
(2,'D02001','M1N2O3P4Q5R6'),(2,'D02002','R6Q5P4O3N2M1'),(2,'D02003','ABCDEF123456'),
(3,'D03001','P00001PASS01'),(3,'D03002','P00002PASS02'),(3,'D03003','P00003PASS03');
