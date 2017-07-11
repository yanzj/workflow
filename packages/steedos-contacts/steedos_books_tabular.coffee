TabularTables.steedosContactsBooks = new Tabular.Table({
	name: "steedosContactsBooks",
	collection: db.address_books,
	columns: [
		{
			data: "_id",
			title: '<input type="checkbox" name="reverse" id="reverse">',
			orderable: false,
			width: '1px',
			render: (val, type, doc) ->
				input = '<input type="checkbox" class="contacts-list-checkbox" name="contacts_ids" id="contacts_ids" value="' + doc._id + '" data-name="' + doc.name + '" data-email="' + doc.email + '"'
				input += ">"
				return input
		},
		{
			data: "name",
			orderable: false,
			render: (val, type, doc) ->
				return "<div class='contacts-name'>" + doc.name + "</div>"
		},
		{
			data: "email",
			orderable: false,
			render: (val, type, doc) ->
				return "<div class='contacts-email'>" + doc.email + "</div>"
		},
		{
			data: "mobile",
			orderable: false,
			render: (val, type, doc) ->
				if doc.mobile
					return "<div class='contacts-mobile'>" + doc.mobile + "</div>"
		},
		{
			data: "company",
			orderable: false,
			render: (val, type, doc) ->
				if doc.company
					return "<div class='contacts-company'>" + doc.company + "</div>"
		},
		{
			data: "",
			title: "",
			orderable: false,
			width: '1px',
			render: (val, type, doc) ->
				return '<button type="button" class="btn btn-xs btn-primary" id="steedos_contacts_group_book_list_edit_btn" data-id="' + doc._id + '"><i class="fa fa-pencil"></i></button>'
		},
		{
			data: "",
			title: "",
			orderable: false,
			width: '1px',
			render: (val, type, doc) ->
				return '<button type="button" class="btn btn-xs btn-primary" id="steedos_contacts_group_book_list_remove_btn" data-id="' + doc._id + '"><i class="fa fa-times"></i></button>'
		}
	],

#select:
#  style: 'single'
	dom: "tp",
	order: [],
	extraFields: ["_id", "name", "email"],
	lengthChange: false,
	pageLength: 15,
	info: false,
	searching: true,
	responsive:
		details: false
	autoWidth: false,
	changeSelector: (selector, userId) ->
		unless userId
			return {_id: -1}
		owner = selector.owner
		unless owner
			if selector?.$and?.length > 0
				owner = selector.$and.getProperty('owner')[0]
		unless owner
			return {_id: -1}
		unless owner.toString() == userId.toString()
			return {_id: -1}
		return selector

#scrollY:        '400px',
#scrollCollapse: true,
	pagingType: "numbers"

});