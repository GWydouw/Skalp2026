// update renewaldate to created date + 1 year
update license set maintenance_renewal_date = DATE_ADD( created_on, INTERVAL 1 YEAR) where license_type = "full" or license_type = "activation";

