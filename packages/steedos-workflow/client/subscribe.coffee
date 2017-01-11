Steedos.instanceSpace = new SubsManager();

Steedos.flowSpace = new SubsManager();

Steedos.formSpace = new SubsManager();

Steedos.subscribeInstance = (instance)->
#	console.log("instance.space: #{instance.space}, instance.flow: #{instance.flow}, instance.flow_version: #{instance.flow_version}")

	if !db.flows.findOne({_id: instance.flow, $or:[{"current._id":instance.flow_version},{"historys._id" : instance.flow_version}]})
		Steedos.flowSpace.clear();

	if !db.forms.findOne({_id: instance.form, $or:[{"current._id":instance.form_version},{"historys._id" : instance.form_version}]})
		Steedos.formSpace.clear();

	Steedos.flowSpace.subscribe("flow", instance.space, instance.flow, instance.flow_version)
	Steedos.formSpace.subscribe("form", instance.space, instance.form, instance.form_version)
	Steedos.instanceSpace.subscribe("instance_data", instance._id)


Tracker.autorun (c)->
#	console.log("subscribe instance...");
	instanceId = Session.get("instanceId")
	#	Steedos.instanceSpace.clear(); # 清理已订阅数据
	if instanceId
		instance = db.instances.findOne({_id: instanceId});

		if instance
			Steedos.subscribeInstance(instance);
		else
			Steedos.instanceSpace.subscribe("instance_data", instanceId)

Tracker.autorun (c) ->
	if Steedos.instanceSpace.ready()
		if Session.get("instanceId")
			instance = db.instances.findOne({_id: Session.get("instanceId")});
			if !instance
				FlowRouter.go("/workflow/space/" + Session.get("spaceId") + "/" + Session.get("box") + "/")
				Session.set("instance_loading", false);