billingManager = {}

# 获得结算周期内的可结算日数
# space_id 结算对象工作区
# accounting_month 结算月，格式：YYYYMM
billingManager.get_accounting_period = (space_id, accounting_month)->
	count_days = 0

	end_date_time = new Date(parseInt(accounting_month.slice(0,4)), parseInt(accounting_month.slice(4,6)), 0)
	end_date = moment(end_date_time.getTime()).format('YYYYMMDD')

	billing = db.billings.findOne({space: space_id, transaction: "Starting balance"})
	first_date = billing.billing_date

	start_date = accounting_month + "01"
	start_date_time = new Date(parseInt(accounting_month.slice(0,4)), parseInt(accounting_month.slice(4,6)), 1-end_date_time.getDate())

	if first_date >= end_date # 这个月不在本次结算范围之内，count_days=0
		# do nothing
	else if start_date <= first_date and first_date < end_date
		count_days = (end_date_time - start_date_time)/(24*60*60*1000) + 1
	else if first_date < start_date
		count_days = (end_date_time - start_date_time)/(24*60*60*1000) + 1

	return {"count_days": count_days}

# 重算这一日的余额
billingManager.refresh_balance = (space_id, refresh_date)->
	last_bill = null
	bill = db.billings.findOne({space: space_id, created: refresh_date})

	# 获取正常付款的小于refresh_date的最近的一条记录
	payment_bill = db.billings.findOne(
		{
			space: space_id,
			created: {
				$lt: refresh_date
			},
			billing_month: bill.billing_month
		},
		{
			sort: {
				modified: -1
			}
		}
	)
	if payment_bill
		last_bill = payment_bill
	else
		# 获取最新的结算的一条记录
		b_m_d = new Date(parseInt(bill.billing_month.slice(0,4)), parseInt(bill.billing_month.slice(4,6)), 0)
		b_m = moment(b_m_d.getTime()-(b_m_d.getDate()*24*60*60*1000)).format("YYYYMM")

		app_bill = db.billings.findOne(
			{
				space: space_id,
				billing_month: b_m
			},
			{
				sort: {
					modified: -1
				}
			}
		)
		if app_bill
			last_bill = app_bill

	last_balance = if last_bill and last_bill.balance then last_bill.balance else 0.0

	debits = if bill.debits then bill.debits else 0.0
	credits = if bill.credits then bill.credits else 0.0
	setObj = new Object
	setObj.balance = Number((last_balance + credits - debits).toFixed(2))
	setObj.modified = new Date
	db.billings.direct.update({_id: bill._id}, {$set: setObj})

# 结算当月的支出与余额
billingManager.get_balance = (space_id, accounting_month, user_count, count_days, module_name, listprice)->
	accounting_date = new Date(parseInt(accounting_month.slice(0,4)), parseInt(accounting_month.slice(4,6)), 0)
	days_number = accounting_date.getDate()
	accounting_date_format = moment(accounting_date).format("YYYYMMDD")

	debits = Number(((count_days/days_number) * user_count * listprice).toFixed(2))
	last_bill = db.billings.findOne(
		{
			space: space_id,
			billing_date: {
				$lte: accounting_date_format
			}
		},
		{
			sort: {
				modified: -1
			}
		}
	)
	last_balance = if last_bill and last_bill.balance then last_bill.balance else 0.0

	now = new Date
	new_bill = new Object
	new_bill._id = db.billings._makeNewID()
	new_bill.billing_month = accounting_month
	new_bill.billing_date = accounting_date_format
	new_bill.space = space_id
	new_bill.transaction = module_name
	new_bill.listprice = listprice
	new_bill.user_count = user_count
	new_bill.debits = debits
	new_bill.balance = Number((last_balance - debits).toFixed(2))
	new_bill.created = now
	new_bill.modified = now
	db.billings.direct.insert(new_bill)

billingManager.getSpaceUserCount = (space_id)->
	db.space_users.find({space: space_id, user_accepted: true}).count()

billingManager.recaculateBalance = (accounting_month, space_id)->
	refresh_dates = new Array
	db.billings.find(
		{
			billing_month: accounting_month,
			space: space_id,
			transaction: {$in: ["Payment", "Service adjustment"]}
		},
		{
			sort: {created: 1}
		}
	).forEach (bill)->
		refresh_dates.push(bill.created)

	if refresh_dates.length > 0
		_.each refresh_dates, (r_d)->
			billingManager.refresh_balance(space_id, r_d)

billingManager.get_modules = (space_id, accounting_month)->
	modules = new Array
	start_date = accounting_month + "01"
	end_date_time = new Date(parseInt(accounting_month.slice(0,4)), parseInt(accounting_month.slice(4,6)), 0)
	end_date = moment(end_date_time.getTime()).format('YYYYMMDD')

	db.modules.find().forEach (m)->
		m_changelog = db.modules_changelogs.findOne(
			{
				space: space_id,
				module: m.name,
				change_date: {
					$lte: end_date
				}
			},
			{
				created: -1
			}
		)
		# 若未获得可匹配的记录，说明该module未安装，当月不计算费用
		if not m_changelog
			#  do nothing

		# 若该记录的change_date<startdate & operation=“install”，说明当月前已安装，因此需计算费用，将module_name与modules.listprice加入modules数组中
		else if m_changelog.change_date < start_date and m_changelog.operation == "install"
			modules.push(m)
		# 若该记录的change_date<startdate & operation=“uninstall”，说明当月前已卸载，因此不计算费用
		else if m_changelog.change_date < start_date and m_changelog.operation == "uninstall"
			#  do nothing
		# 若该记录的change_date≥startdate，说明当月内发生过安装或卸载的操作，需计算费用，将module_name与modules.listprice加入modules数组中
		else if m_changelog.change_date >= start_date
			modules.push(m)

	return modules

billingManager.get_modules_name = ()->
	modules_name = new Array
	db.modules.find().forEach((m)->
		modules_name.push(m.name)
	)
	return modules_name


billingManager.caculate_by_accounting_month = (accounting_month, space_id)->
	if accounting_month > (moment().format('YYYYMM'))
		return
	if accounting_month == (moment().format('YYYYMM'))
		# 重算当月的充值后余额
		billingManager.recaculateBalance(accounting_month, space_id)

		debits = 0
		modules_name = billingManager.get_modules_name()
		b_m_d = new Date(parseInt(accounting_month.slice(0,4)), parseInt(accounting_month.slice(4,6)), 0)
		b_m = moment(b_m_d.getTime()-(b_m_d.getDate()*24*60*60*1000)).format("YYYYMMDD")
		db.billings.find(
			{
				billing_date: b_m,
				space: space_id,
				transaction: {
					$in: modules_name
				}
			}
		).forEach((b)->
			debits += b.debits
		)
		newest_bill = db.billings.findOne({space: space_id}, {sort: {modified: -1}})
		balance = newest_bill.balance
		remaining_months = 0
		if balance > 0
			if debits > 0
				remaining_months = parseInt(balance/debits) + 1
			else
				# 当月刚升级，并没有扣款
				remaining_months = 1

		db.spaces.direct.update(
			{
				_id: space_id
			},
			{
				$set: {
					balance: balance,
					"billing.remaining_months": remaining_months
				}
			}
		)
	else
		# 获得其结算对象日期paymentdates数组和count_days可结算日数
		period_result = billingManager.get_accounting_period(space_id, accounting_month)
		if period_result["count_days"] == 0
			# 也需对当月的充值记录执行更新
			billingManager.recaculateBalance(accounting_month, space_id)

		else
			user_count = billingManager.getSpaceUserCount(space_id)

			# 清除当月的已结算记录
			modules_name = billingManager.get_modules_name()
			accounting_date = new Date(parseInt(accounting_month.slice(0,4)), parseInt(accounting_month.slice(4,6)), 0)
			accounting_date_format = moment(accounting_date).format("YYYYMMDD")
			db.billings.remove(
				{
					billing_date: accounting_date_format,
					space: space_id,
					transaction: {
						$in: modules_name
					}
				}
			)
			# 重算当月的充值后余额
			billingManager.recaculateBalance(accounting_month, space_id)

			# 结算当月的APP使用后余额
			modules = billingManager.get_modules(space_id, accounting_month)
			if modules and  modules.length>0
				_.each modules, (m)->
					billingManager.get_balance(space_id, accounting_month, user_count, period_result["count_days"], m.name, m.listprice)

		a_m = moment(new Date(parseInt(accounting_month.slice(0,4)), parseInt(accounting_month.slice(4,6)), 1).getTime()).format("YYYYMM")
		billingManager.caculate_by_accounting_month(a_m, space_id)

billingManager.special_pay = (space_id, module_id, total_fee, operator_id)->
	console.log "============billingManager.special_pay"
	amount = (total_fee/100) * (3/20) 
	space = db.spaces.findOne(space_id)
	
	module = db.modules.findOne(module_id)

	module_name = module.name

	modules = space.modules || new Array
	
	new_modules = new Array
	if !modules.includes(module_name)
		new_modules.push(module_name)

	transaction = "Payment"

	m = moment()
	now = m._d

	space_update_obj = new Object

	# 检查此工作区是否已经生成了Billing
	pay_count = db.billings.find({space: space_id}).count()
	# 若记录数≠0，说明该工作区不是第一次付费，跳过这个步骤
	# 若记录数=0，说明该工作区第一次付费，因此执行以下操作
	if pay_count is 0
		# 先执行初始化账户的操作
		bill = new Object
		bill._id = db.billings._makeNewID()
		bill.billing_month = m.format("YYYYMM")
		bill.billing_date = m.format("YYYYMMDD")
		bill.operator = operator_id
		bill.space = space_id
		bill.transaction = "Starting balance"
		bill.created = now
		bill.created_by = operator_id
		bill.modified = now

		bill_id = db.billings.insert(bill)
		if bill_id
			# 更新space是否专业版的标记
			if space.is_paid isnt true
				space_update_obj.is_paid = true

	# 在billings中插入付费信息
	last_bill = db.billings.findOne({space: space_id},{sort:{modified: -1}, limit: 1})
	last_balance = if last_bill.balance then last_bill.balance else 0.0

	new_bill = new Object
	new_bill._id = db.billings._makeNewID()
	new_bill.billing_month = m.format("YYYYMM")
	new_bill.billing_date = m.format("YYYYMMDD")
	new_bill.operator = operator_id
	new_bill.space = space_id
	new_bill.transaction = transaction
	new_bill.credits = Number(amount.toFixed(2))
	new_bill.balance = Number((last_balance + amount).toFixed(2))
	new_bill.created = now
	new_bill.created_by = operator_id
	new_bill.modified = now
	
	new_bill_id = db.billings.insert(new_bill)
	if new_bill_id
		# 更新modules
		modules.push(module_name)
		space_update_obj.modules = _.uniq(modules)
		space_update_obj.balance = new_bill.balance
		space_update_obj.modified = now
		space_update_obj.modified_by = operator_id

		r = db.spaces.direct.update({_id: space_id}, {$set: space_update_obj})
		if r
			console.log r
			_.each new_modules, (m)->
				mcl = new Object
				mcl._id = db.modules_changelogs._makeNewID()
				mcl.change_date = m.format("YYYYMMDD")
				mcl.operator = operator_id
				mcl.space = space_id
				mcl.operation = "install"
				mcl.module = m
				mcl.created = now
				db.modules_changelogs.insert(mcl)
			# 重新结算以更新remaining_months
			billingManager.caculate_by_accounting_month(m.format("YYYYMM"), space_id)

	return