Template.phonePrefixesSelect.helpers({
	prefixes: function(){
		var value = this.value;
		var selectedCode = this.selected;
		if(!selectedCode){
			var language = (navigator.language || navigator.browserLanguage).toLowerCase();
			var tags = language.match(/-([^-]+)/g);
			if(tags && tags.length){
				selectedCode = tags[tags.length - 1].replace("-","");
			}
			else{
				selectedCode = language ? language : "CN";
			}
		}
		selectedCode = selectedCode.toUpperCase();
		var locale = this.locale;
		if(!locale){
			locale = "zh-cn";
		}
		var countries = IsoCountries.getNames(locale);
		var options = []; 
		var props,code,name,title,prefixe;
		for(var key in countries){
			props = {};
			code = key;
			name = countries[key]
			prefixe = E164.findPhoneCountryCode(code);
			if(prefixe){
				title = "+" + prefixe + " " + name;
				if (value ? (prefixe == value) : (code === selectedCode)){
					props = {selected: true};
				}
				options.push({prefixe: prefixe, code: code, name: name, title: title, props: props});
			}
		}
		// 按name排序
		options.sort(function (p1, p2) {
			return p1.name.localeCompare(p2.name, locale);
		});
		return options;
	}
});

