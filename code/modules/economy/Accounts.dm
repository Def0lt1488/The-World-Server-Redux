
/datum/money_account
	var/owner_name = ""
	var/account_number = 0
	var/remote_access_pin = 0
	var/money = 0
	
	var/list/transaction_log = list()
	var/max_transaction_logs = 50
	
	var/suspended = 0
	var/security_level = 0	//0 - auto-identify from worn ID, require only account number
							//1 - require manual login / account number and pin
							//2 - require card and manual login

	var/list/datum/expense/expenses = list()		//list of debts and expenses
	var/department

	var/fingerprint

/datum/transaction
	var/target_name = ""
	var/purpose = ""
	var/amount = 0
	var/date = ""
	var/time = ""
	var/source_terminal = ""
	var/target_ckey = "n/a" //kept on admin side, for monitoring. n/a by default.

/proc/create_account(var/new_owner_name = "Default user", var/starting_funds = 0, var/obj/machinery/account_database/source_db)

	//create a new account
	var/datum/money_account/M = new()
	M.owner_name = new_owner_name
	M.remote_access_pin = rand(1111, 9999)
	M.money = starting_funds
	M.security_level = 1

	//create an entry in the account transaction log for when it was created
	var/datum/transaction/T = new()
	T.target_name = new_owner_name
	T.purpose = "Account creation"
	T.amount = starting_funds
	if(!source_db)
		//set a random date, time and location some time over the past few decades
		T.date = "[get_game_day()] [get_month_from_num(get_game_month())], [get_game_year()]"
		T.time = stationtime2text()
		T.source_terminal = "NTGalaxyNet Terminal #[rand(111,1111)]"

		M.account_number = md5("[station_name()][current_date_string]")
	else
		T.date = current_date_string
		T.time = stationtime2text()
		T.source_terminal = source_db.machine_id

		M.account_number = next_account_number
		next_account_number += rand(1,25)

		//create a sealed package containing the account details
		var/obj/item/smallDelivery/P = new /obj/item/smallDelivery(source_db.loc)

		var/obj/item/weapon/paper/R = new /obj/item/weapon/paper(P)
		P.wrapped = R
		R.name = "Account information: [M.owner_name]"
		R.info = "<b>Account details (confidential)</b><br><hr><br>"
		R.info += "<i>Account holder:</i> [M.owner_name]<br>"
		R.info += "<i>Account number:</i> [M.account_number]<br>"
		R.info += "<i>Account pin:</i> [M.remote_access_pin]<br>"
		R.info += "<i>Starting balance:</i> $[M.money]<br>"
		R.info += "<i>Date and time:</i> [stationtime2text()], [stationdate2text()]<br><br>"
		R.info += "<i>Creation terminal ID:</i> [source_db.machine_id]<br>"
		R.info += "<i>Authorised NT officer overseeing creation:</i> [source_db.held_card.registered_name]<br>"

		//stamp the paper
		var/image/stampoverlay = image('icons/obj/bureaucracy.dmi')
		stampoverlay.icon_state = "paper_stamp-cent"
		if(!R.stamped)
			R.stamped = new
		R.stamped += /obj/item/weapon/stamp
		R.overlays += stampoverlay
		R.stamps += "<HR><i>This paper has been stamped by the Accounts Database.</i>"

	//add the account
	M.transaction_log.Add(T)
	all_money_accounts.Add(M)

	return M

/proc/charge_to_account(var/attempt_account_number, var/source_name, var/purpose, var/terminal_id, var/amount)

	for(var/datum/money_account/D in all_money_accounts)
		if(D.account_number == attempt_account_number && !D.suspended || D.account_number == attempt_account_number && !D.suspended)
			D.money += amount
			//create a transaction log entry
			
			D.add_transaction_log(source_name, purpose, amount, terminal_id)
			return 1


	if(config.canonicity)
		if(check_persistent_account(attempt_account_number) && !get_persistent_acc_suspension(attempt_account_number))
			
			//create a transaction log entry
			var/datum/transaction/T = new()
			T.target_name = source_name
			T.purpose = purpose
			if(amount < 0)
				T.amount = "([amount])"
			else
				T.amount = "[amount]"
			T.date = current_date_string
			T.time = stationtime2text()
			T.source_terminal = terminal_id
			
			persist_adjust_balance(attempt_account_number, amount)
			add_persistent_acc_logs(account_number, T)

			return 1

	return 0

//this returns the first account datum that matches the supplied accnum/pin combination, it returns null if the combination did not match any account
/proc/attempt_account_access(var/attempt_account_number, var/attempt_pin_number, var/security_level_passed = 0)
	for(var/datum/money_account/D in all_money_accounts)
		if(D.account_number == attempt_account_number)
			if( D.security_level <= security_level_passed && (!D.security_level || D.remote_access_pin == attempt_pin_number) )
				return D
			break

/proc/get_account(var/account_number)
	for(var/datum/money_account/D in all_money_accounts)
		if(D.account_number == account_number)
			return D
			
// why was this never made until now?
/datum/money_account/proc/add_transaction_log(name, purpose, amount, terminal_id, date, time)
	var/datum/transaction/T = new()
	
	T.name = name
	T.purpose = purpose
	
	if(amount < 0)
		T.amount = "(-[amount])"
	else
		T.amount = "[amount]"
		
	if(date)
		T.date = date
	else
		T.date = current_date_string
		
	if(time)
		T.time = time
	else
		T.time = stationtime2text()
		
	if(terminal_id)
		T.source_terminal = terminal_id
	else
		T.source_terminal = "Terminal #[rand(111,999)]"
		
	transaction_log.Add(T)
	truncate_oldest(transaction_log, max_transaction_logs)
