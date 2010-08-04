var elements = [];
var active_arr = [];
var hints;
var overlays;
var active;
var lastpos = 0;
var last_input = "";
var last_strings = [];

focus_color = "#00ff00";
normal_color = "#ffff99";
opacity = 0.3;
border = "1px dotted #000000";

hint_foreground = "#ffffff";
hint_background = "#000088";
hint_border = "2px dashed #000000";
hint_opacity = 0.4;
hint_font =  "11px monospace bold";

vertical_offset = 0;
horizontal_offset = -10;

function Hint(element) {
  this.element = element;
  this.rect = element.getBoundingClientRect();

  function create_span(element, h, v) {
    var span = document.createElement("span");
    var leftpos = Math.max((element.rect.left + document.defaultView.scrollX), document.defaultView.scrollX) + h;
    var toppos = Math.max((element.rect.top + document.defaultView.scrollY), document.defaultView.scrollY) + v;
    span.style.position = "absolute";
    span.style.left = leftpos + "px";
    span.style.top = toppos + "px";
    return span;
  }
  function create_hint(element) {
    var hint = create_span(element, horizontal_offset, vertical_offset - element.rect.height/2);
    hint.style.font = hint_font;
    hint.style.color = hint_foreground;
    hint.style.background = hint_background;
    hint.style.opacity = hint_opacity;
    hint.style.border = hint_border;
    hint.style.zIndex = 10001;
    hint.style.visibility = 'visible';
    return hint;
  }
  function create_overlay(element) {
    var overlay = create_span(element, 0, 0);
    overlay.style.width = element.rect.width + "px";
    overlay.style.height = element.rect.height + "px";
    overlay.style.opacity = opacity;
    overlay.style.backgroundColor = normal_color;
    overlay.style.border = border;
    overlay.style.zIndex = 10000;
    overlay.style.visibility = 'visible';
    overlay.addEventListener( 'click', function() { click_element(element); }, false );
    return overlay;
  }

  this.hint = create_hint(this);
  this.overlay = create_overlay(this);
}
function reload_hints(array, input, keep) {
  var length = array.length;
  var start = length < 10 ? 1 : length < 100 ? 10 : 100;
  var bestposition = 37;

  for (var i=0; i<length; i++) {
    var e = array[i];
    e.overlay.style.backgroundColor = normal_color;
    if (!e.hint.parentNode  && !e.hint.firstchild) {
      var content = document.createTextNode(start + i);
      e.hint.appendChild(content);
      hints.appendChild(e.hint);
    }
    else if (!keep) {
      e.hint.textContent = start + i;
    }
    if (!e.overlay.parentNode && !e.overlay.firstchild) {
      overlays.appendChild(e.overlay);
    }
    if (input && bestposition != 0) {
      // match word beginnings
      var content = e.element.textContent.toLowerCase().split(" ");
      for (var cl=0; cl<content.length; cl++) {
        if (content[cl].toLowerCase().indexOf(input) == 0) {
          if (cl < bestposition) {
            lastpos = i;
            bestposition = cl;
            break;
          }
        }
      }
    }
  }
  active = array[lastpos];
  active.overlay.style.backgroundColor = focus_color;
}
function click_element(e) {
  var mouseEvent = document.createEvent("MouseEvent");
  mouseEvent.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
  e.element.dispatchEvent(mouseEvent);
  clear();
}
function show_hints() {
  document.activeElement.blur();
  if ( elements ) {
    var res = document.body.querySelectorAll('a, area, textarea, select, link, input:not([type=hidden]), button,  frame, iframe');
    hints = document.createElement("div");
    overlays  = document.createElement("div");
    for (var i=0; i<res.length; i++) {
      var e = new Hint(res[i]);
      var rects = e.element.getClientRects()[0];
      var r = e.rect;
      if (!r || r.top > window.innerHeight || r.bottom < 0 || r.left > window.innerWidth ||  r < 0 || !rects ) {
        continue;
      }
      var style = document.defaultView.getComputedStyle(e.element, null);
      if (style.getPropertyValue("visibility") != "visible" || style.getPropertyValue("display") == "none") {
        continue;
      }
      elements.push(e);
    };
    elements.sort( function(a,b) { return a.rect.top - b.rect.top; });
    active_arr = elements;
    reload_hints(elements);
    document.body.appendChild(hints);
    document.body.appendChild(overlays);
  }
}
function is_input(element) {
  var e = element.element;
  var type = e.type.toLowerCase();
  if (e.tagName == "INPUT" || e.tagName == "TEXTAREA" ) {
    if (type == "radio" || type == "checkbox") {
      e.checked = !e.checked;
    }
    else if (type == "submit" || type == "reset" || type  == "button") {
      click_element(element);
    }
    else {
      e.focus();
    }
    return true;
  }
  return false;
}
function update_hints(input) {
  var array = [];
  var text_content;
  var keep = false;
  if (input) {
    input = input.toLowerCase();
  }
  for (var i=0; i<active_arr.length; i++) {
    var e = active_arr[i];
    if (parseInt(input) == input) {
      text_content = e.hint.textContent;
      keep = true;
    }
    else {
      text_content = e.element.textContent.toLowerCase();
    }
    if (text_content.match(input)) {
      array.push(e);
    }
    else {
      e.hint.style.visibility = 'hidden';
      e.overlay.style.visibility = 'hidden';
    }
  }
  active_arr = array;
  if (array.length == 0) {
    clear();
    return;
  }
  if (array.length == 1) {
    if (evaluate(array[0])) {
        return "__HINT_EVALUATED__"
    }
  }
  reload_hints(array, input, keep);
}
function clear() {
  if (overlays && overlays.parentNode) {
      overlays.parentNode.removeChild(overlays);
  }
  if (hints && hints.parentNode) {
      hints.parentNode.removeChild(hints);
  }
  elements = [];
  active_arr = [];
  active = undefined;
}
function evaluate(element) {
  var ret = false;
  var e = element.element;
  if (!is_input(element) && e.href) {
    if (e.href.match(/javascript:/) || (e.type.toLowerCase() == "button")) {
      click_element(element);
      ret = true;
    }
    else {
      document.location = e.href;
      ret = true;
    }
  }
  clear();
  return ret;
}
function get_active() {
  return evaluate(active);
}
function focus(newpos) {
  active_arr[lastpos].overlay.style.backgroundColor = normal_color;
  active_arr[newpos].overlay.style.backgroundColor = focus_color;
  active = active_arr[newpos];
  lastpos = newpos;
}
function focus_next() {
  var newpos = lastpos == active_arr.length-1 ? 0 : lastpos + 1;
  focus(newpos);
}
function focus_prev() {
  var newpos = lastpos == 0 ? active_arr.length-1 : lastpos - 1;
  focus(newpos);
}

function update(input) {
    input = input.replace(/(\d+)$/, " $1");
    strings = input.split(" ");
    if (input.length < last_input.length || strings.length < last_strings.length) {
        // user removed a char
        clear();
        show_hints();
        for (var i = 0; i < strings.length; i += 1) {
            update_hints(strings[i]);
        }
    } else {
        update_hints(strings[strings.length-1]);
    }
    last_input = input;
    last_strings = strings;
}

