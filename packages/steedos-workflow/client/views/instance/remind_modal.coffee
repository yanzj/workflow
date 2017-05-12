Template.remind_modal.helpers
	user_context: ()->
		ins = WorkflowManager.getInstance();
		if !ins
			return false

		last_trace = _.last(ins.traces)
		this.trace_id = last_trace._id

		users_id = new Array
		users = new Array

		if this.action_type is 'admin'
			_.each last_trace.approves, (ap)->
				if ap.is_finished isnt true
					users_id.push(ap.user)
					users.push({id: ap.user, name: ap.user_name})
		else if this.action_type is 'applicant'
			_.each last_trace.approves, (ap)->
				if ap.is_finished isnt true and ap.type is undefined
					users_id.push(ap.user)
					users.push({id: ap.user, name: ap.user_name})
		else if this.action_type is 'cc'
			_.each last_trace.approves, (ap)->
				if ap.is_finished isnt true and ap.type is 'cc'
					users_id.push(ap.user)
					users.push({id: ap.user, name: ap.user_name})

		data = {
			value: users
			dataset: {
				showOrg: false,
				multiple: true,
				userOptions: users_id,
				values: users_id.toString()
			},
			name: 'instance_remind_select_users',
			atts: {
				name: 'instance_remind_select_users',
				id: 'instance_remind_select_users',
				class: 'selectUser form-control'
			}
		}

		return data

	deadline_fields: ()->
		if Steedos.isAndroidOrIOS()
			return new SimpleSchema({
				remind_deadline: {
					autoform: {
						type: "datetime-local"
					},
					optional: true,
					type: Date,
					label: TAPi18n.__('instance_remind_deadline')
				}
			})
		else
			return new SimpleSchema({
				remind_deadline: {
					autoform: {
						type: "bootstrap-datetimepicker"
						dateTimePickerOptions:{
							format: "YYYY-MM-DD HH:mm"
						}
					},
					optional: true,
					type: Date,
					label: TAPi18n.__('instance_remind_deadline')
				}
			})

	deadline_values: ()->
		return {}

	disabled: ()->
		if this.action_type isnt "admin"
			return true

		return false

	remind_count_options: ()->
		return [{
			value: "single",
			name: TAPi18n.__("instance_remind_count_options.single")
		}, {
			value: "multi",
			name: TAPi18n.__("instance_remind_count_options.multi")
		}]

Template.remind_modal.onRendered ()->
	console.log "remind_modal onRendered"
	$("#remind_modal .modal-body").css("max-height", Steedos.getModalMaxHeight())
	
Template.remind_modal.events
	'click #instance_remind_ok': (event, template)->
		values = $("#instance_remind_select_users")[0].dataset.values
		remind_users = if values then values.split(",") else []
		remind_count = $('#instance_remind_count').val()
		remind_deadline = AutoForm.getFieldValue("remind_deadline", "instance_remind_deadline")

		if _.isEmpty(remind_users)
			toastr.error TAPi18n.__('instance_remind_need_remind_users')
			return

		if not remind_count
			toastr.error TAPi18n.__('instance_remind_need_remind_count')
			return

		if not remind_deadline
			toastr.error TAPi18n.__('instance_remind_need_remind_deadline')
			return

		if template.data.action_type isnt "admin"
			remind_count = 'single'

		$("body").addClass("loading")
		Meteor.call 'instance_remind', remind_users, remind_count, remind_deadline, Session.get('instanceId'), template.data.trace_id, (err, result)->
			$("body").removeClass("loading")
			if err
				toastr.error TAPi18n.__(err.reason)
			if result == true
				toastr.success(t("instance_remind_success"))
				Modal.hide template
			return



	