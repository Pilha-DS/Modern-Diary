USE `MDiary`;

-- ########## Roles ##########
-- Admin: Has full access to the system
-- Moderator: Has access to the moderation tools
-- Subscriber: Has access to the subscriber tools
-- User: Has access to the user tools
-- Visitor: Has access to the visitor tools
-- Banned: Has been banned from the system

INSERT INTO `roles` (`name`) VALUES ('admin');

INSERT INTO `roles` (`name`) VALUES ('user');
INSERT INTO `roles` (`name`) VALUES ('visitor');
INSERT INTO `roles` (`name`) VALUES ('banned');

-- ########## Countries ##########

INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('AE', 'ARE', 784, 971, 'United Arab Emirates');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('AF', 'AFG', 4, 93, 'Afghanistan');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('AL', 'ALB', 8, 355, 'Albania');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('AM', 'ARM', 51, 374, 'Armenia');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('AO', 'AGO', 24, 244, 'Angola');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('AR', 'ARG', 32, 54, 'Argentina');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('AT', 'AUT', 40, 43, 'Austria');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('AU', 'AUS', 36, 61, 'Australia');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('AZ', 'AZE', 31, 994, 'Azerbaijan');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BA', 'BIH', 70, 387, 'Bosnia and Herzegovina');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BB', 'BRB', 52, 1246, 'Barbados');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BD', 'BGD', 50, 880, 'Bangladesh');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BE', 'BEL', 56, 32, 'Belgium');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BF', 'BFA', 854, 226, 'Burkina Faso');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BG', 'BGR', 100, 359, 'Bulgaria');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BH', 'BHR', 48, 973, 'Bahrain');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BI', 'BDI', 108, 257, 'Burundi');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BJ', 'BEN', 204, 229, 'Benin');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BN', 'BRN', 96, 673, 'Brunei');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BO', 'BOL', 68, 591, 'Bolivia');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BR', 'BRA', 76, 55, 'Brazil');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BS', 'BHS', 44, 1242, 'Bahamas');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BT', 'BTN', 64, 975, 'Bhutan');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BW', 'BWA', 72, 267, 'Botswana');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BY', 'BLR', 112, 375, 'Belarus');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('BZ', 'BLZ', 84, 501, 'Belize');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CA', 'CAN', 124, 1, 'Canada');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CD', 'COD', 180, 243, 'Congo (Democratic Republic of the)');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CF', 'CAF', 140, 236, 'Central African Republic');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CG', 'COG', 178, 242, 'Congo (Republic of the)');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CH', 'CHE', 756, 41, 'Switzerland');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CI', 'CIV', 384, 225, 'Côte d Ivoire');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CL', 'CHL', 152, 56, 'Chile');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CM', 'CMR', 120, 237, 'Cameroon');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CN', 'CHN', 156, 86, 'China');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CO', 'COL', 170, 57, 'Colombia');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CR', 'CRI', 188, 506, 'Costa Rica');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CU', 'CUB', 192, 53, 'Cuba');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CV', 'CPV', 132, 238, 'Cape Verde');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CY', 'CYP', 196, 357, 'Cyprus');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('CZ', 'CZE', 203, 420, 'Czechia');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('DE', 'DEU', 276, 49, 'Germany');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('DJ', 'DJI', 262, 253, 'Djibouti');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('DK', 'DNK', 208, 45, 'Denmark');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('DO', 'DOM', 214, 1809, 'Dominican Republic');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('DZ', 'DZA', 12, 213, 'Algeria');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('EC', 'ECU', 218, 593, 'Ecuador');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('EE', 'EST', 233, 372, 'Estonia');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('EG', 'EGY', 818, 20, 'Egypt');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('ER', 'ERI', 232, 291, 'Eritrea');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('ES', 'ESP', 724, 34, 'Spain');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('ET', 'ETH', 231, 251, 'Ethiopia');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('FI', 'FIN', 246, 358, 'Finland');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('FJ', 'FJI', 242, 679, 'Fiji');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('FK', 'FLK', 238, 500, 'Falkland Islands (Malvinas)');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('FR', 'FRA', 250, 33, 'France');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GA', 'GAB', 266, 241, 'Gabon');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GB', 'GBR', 826, 44, 'United Kingdom');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GD', 'GRD', 308, 1473, 'Grenada');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GE', 'GEO', 268, 995, 'Georgia');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GH', 'GHA', 288, 233, 'Ghana');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GI', 'GIB', 292, 350, 'Gibraltar');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GL', 'GRL', 304, 299, 'Greenland');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GM', 'GMB', 270, 220, 'Gambia');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GN', 'GIN', 324, 224, 'Guinea');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GQ', 'GNQ', 226, 240, 'Equatorial Guinea');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GR', 'GRC', 300, 30, 'Greece');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GT', 'GTM', 320, 502, 'Guatemala');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GW', 'GNB', 624, 245, 'Guinea-Bissau');
INSERT INTO `countries` (`iso_alpha2`, `iso_alpha3`, `iso_numeric`, `phone_code`, `name_en`) VALUES ('GY', 'GUY', 328, 592, 'Guyana');