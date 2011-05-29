// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

I18n.defaultLocale = "zh-CN";
I18n.locale = "zh-CN";
I18n.currentLocale();

var period = 3600*1000 //Default 1 hour period

function get_date(value){
    firstParts = value.split(" ")
    secondParts = firstParts[1].split(":")
    hour = parseInt(secondParts[0])
    min = parseInt(secondParts[1])
    result = new Date(firstParts[0])
    result.setHours(hour, min, 0, 0)
    return result
}

function on_change_begin(begin_id, end_id){
    currentBegin = get_date($(begin_id).val())
    newEndInt = Date.parse(currentBegin) + period;
    newEnd = new Date(newEndInt);
    newValue = newEnd.toFormattedString('%Y-%m-%d %T')
    if (newValue != "NaN-NaN-NaN NaN:NaN")
    $(end_id).val(newEnd.toFormattedString('%Y-%m-%d %T'))
}

function on_change_end(begin_id, end_id){
    currentBegin = get_date($(begin_id).val())
    currentEnd= get_date($(end_id).val())
    period = Date.parse(currentEnd)-Date.parse(currentBegin)
}

function show_repeat_options(type, div_id)
{
    if (div_id == null)
    {
        div_id = 'repeat_options';
    }

    if (type == "NONE" && $(div_id).visible())
    {
        Effect.BlindUp(div_id, {duration: 0.2});
    }
    else if (type != "NONE" && ! $(div_id).visible())
    {
        Effect.BlindDown(div_id, {duration: 0.2});
    }

    $("repeat_legend").innerHTML = I18n.t("tongshare.event.recurrence." + type.toLowerCase());

    if(type != "NONE")
    {
        $("interval_suffix").innerHTML = I18n.t("tongshare.event.recurrence.interval_suffix_" + type.toLowerCase());
    }

    switch(type)
    {
        case "NONE":
            $("rrule_days_panel").hide();
            break;

        case "WEEKLY":
            $("rrule_days_panel").show();
            break;  //TODO: show specific options for different types

        case "DAILY":
            $("rrule_days_panel").hide();
            break;
    }
}
