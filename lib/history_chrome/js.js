$(document).ready(function ()
{ 'use strict';
  
  var limit = 100, page = 1, results_len = 0;
  
  var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  var days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  
  var item_html = $("#item-skelly").html();
  $("#templates").remove();
  
  function make_history_item(h) {
      var $e = $(item_html);
      $e.attr("history_id", h.id);
      $e.find(".visits").text(h.visits);
      $e.find(".time").text(h.time);
      $e.find(".title a")
          .attr("href", h.uri)
          .text(h.title || h.uri);
      var domain = /:\/\/([^/]+)\//.exec(h.uri);
                  $e.find(".domain a").text(domain && domain[1] || "");
                  return $e.prop("outerHTML");
                 };

var $search = $('#search').eq(0),
    $results = $('#results').eq(0),
    $results_header = $("#results-header").eq(0),
    $clear_all = $("#clear-all-button").eq(0),
    $clear_results = $("#clear-results-button").eq(0),
    $clear_selected = $("#clear-selected-button").eq(0),
    $next = $("#nav-next").eq(0),
    $prev = $("#nav-prev").eq(0);

function update_clear_buttons(all, results, selected) {
    $clear_all.attr("disabled", !!all);
    $clear_results.attr("disabled", !!results);
    $clear_selected.attr("disabled", !!selected);
}

function update_nav_buttons() {
    if (results_len === limit)
        $next.show();
    else
        $next.hide();
    if (page > 1)
        $prev.show();
    else
        $prev.hide();
}

function search() {
    var query = $search.val(),
        results = history_search({
            query: query, limit: limit, page: page });
    
    // Used to trigger hiding of next nav button when results_len < limit
    results_len = results.length || 0;
    
    update_clear_buttons(query, !query, true);
    
    if (!results.length) {
        $results.empty();
        update_nav_buttons();
        return;
    }
    
    var last_date, last_time = 0, group_html;
    
    var i = 0, len = results.length, html = "";
    
    var sep = $("<div/>").addClass("day-sep").prop("outerHTML"),
        $heading = $("<div/>").addClass("day-heading");
    
    for (; i < len;) {
        var h = results[i++];
        
        if (h.date !== last_date) {
            last_date = h.date;
            html += $heading.text(h.date).prop("outerHTML");
            
        } else if ((last_time - h.last_visit) > 3600)
            html += sep;
        
        last_time = h.last_visit;
        html += make_history_item(h);
    }
    
    update_nav_buttons(query);
    
    $results.get(0).innerHTML = html;
}

/* input field callback */
$search.keydown(function(ev) {
    if (ev.which == 13) { /* Return */
        reset_mode();
        page = 1;
        search();
        $search.blur();
    }
});

$("#clear-button").click(function () {
    $search.val("");
    page = 1;
    search();
});

$("#search-button").click(function () {
    page = 1;
    search();
});

// Auto search history by domain when clicking on domain
$results.on("click", ".item .domain a", function (e) {
    $search.val($(this).text());
    search();
});

// Select items & enable/disable clear all selected button
$results.on("click", ".item", function (e) {
    var $e = $(this);
    if ($e.hasClass("selected")) {
        $(this).removeClass("selected");
        if ($results.find(".selected").length === 0)
            $clear_selected.attr("disabled", true);
    } else {
        $(this).addClass("selected");
        $clear_selected.attr("disabled", false);
    }
});

$clear_all.click(function () {
    if (confirm("Clear all browsing history?")) {
        history_clear_all();
        $results.fadeOut("fast", function () {
            $results.empty();
            $results.show();
            search();
        });
        $clear_all.blur();
    }
});

$next.click(function () {
    page++;
    search();
});

$prev.click(function () {
    page = Math.max(page-1,1);
    search();
});

function clear_elems($elems) {
    var ids = [], last = $elems.length - 1;
    
    $elems.each(function (index) {
        var $e = $(this);
        ids.push($e.attr("history_id"));
        if (index == last)
            $e.fadeOut("fast", function () { search(); });
        else
            $e.fadeOut("fast");
    });
    
    if (ids.length)
        history_clear_list(ids);
};

$clear_results.click(function () {
    clear_elems($results.find(".item"));
    $clear_results.blur();
});

$clear_selected.click(function () {
    clear_elems($results.find(".selected"));
    $clear_selected.blur();
});

var query = initial_search_term();
if (query)
    $search.val(query);

search();
});
