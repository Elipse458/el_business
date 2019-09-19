ALTER TABLE `businesses` CHANGE `id` `id` INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE `businesses` ADD `blipname` VARCHAR(75) NULL DEFAULT NULL AFTER `description`;
ALTER TABLE `businesses` ADD `taxrate` FLOAT NULL AFTER `stock_price`;
ALTER TABLE `businesses` ADD `employees` TEXT NULL AFTER `taxrate`;