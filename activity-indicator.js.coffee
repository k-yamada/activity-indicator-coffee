#
# NETEYE Activity Indicator jQuery Plugin
#
# Copyright (c) 2010 NETEYE GmbH
# Licensed under the MIT license
#
# Author: Felix Gnass [fgnass at neteye dot de]
# Version: 1.0.0
#
 
#
# Plugin that renders a customisable activity indicator (spinner) using SVG or VML.
#
$ ->
  $.fn.activity = (opts) ->
    this.each(->
      $this = $(this)
      el = $this.data('activity')
      if (el)
        clearInterval(el.data('interval'))
        el.remove()
        $this.removeData('activity')
      if opts != false
        opts = $.extend({color: $this.css('color')}, $.fn.activity.defaults, opts)
        el = render($this, opts).css('position', 'absolute').prependTo(if opts.outside then 'body' else $this)
        h = $this.outerHeight() - el.height()
        w = $this.outerWidth() - el.width()
        margin =
          top:  if opts.valign == 'top' then opts.padding else if opts.valign == 'bottom' then h - opts.padding else Math.floor(h / 2)
          left: if opts.align == 'left' then opts.padding else if opts.align == 'right'   then w - opts.padding else Math.floor(w / 2)
        offset = $this.offset()
        if opts.outside
          el.css({top: offset.top + 'px', left: offset.left + 'px'})
        else
          margin.top -= el.offset().top - offset.top
          margin.left -= el.offset().left - offset.left
        el.css({marginTop: margin.top + 'px', marginLeft: margin.left + 'px'})
        animate(el, opts.segments, Math.round(10 / opts.speed) / 10)
        $this.data('activity', el)
    )
    return this
  
  $.fn.activity.defaults = 
    segments: 12
    space: 3
    length: 7
    width: 4
    speed: 1.2
    align: 'center'
    valign: 'center'
    padding: 4
  
  $.fn.activity.getOpacity = (opts, i) ->
    steps = opts.steps || opts.segments-1
    end = if opts.opacity != undefined then opts.opacity else 1/steps
    return 1 - Math.min(i, steps) * (1 - end) / steps
  
  #
  # Default rendering strategy. If neither SVG nor VML is available, a div with class-name 'busy' 
  # is inserted, that can be styled with CSS to display an animated gif as fallback.
  #
  render = ->
    return $('<div>').addClass('busy')
  
  #
  # The default animation strategy does nothing as we expect an animated gif as fallback.
  #
  animate = ->
  
  #
  # Utility function to create elements in the SVG namespace.
  #
  svg = (tag, attr) ->
    el = document.createElementNS("http://www.w3.org/2000/svg", tag || 'svg')
    if attr
      $.each(attr, (k, v) ->
        el.setAttributeNS(null, k, v)
      )
    return $(el)
  
  if document.createElementNS && document.createElementNS( "http://www.w3.org/2000/svg", "svg").createSVGRect
  
    # =======================================================================================
    # SVG Rendering
    # =======================================================================================
    
    #
    # Rendering strategy that creates a SVG tree.
    #
    render = (target, d) ->
      innerRadius = d.width*2 + d.space
      r = (innerRadius + d.length + Math.ceil(d.width / 2) + 1)
      
      el = svg().width(r*2).height(r*2)
      
      g = svg('g', 
        'stroke-width': d.width
        'stroke-linecap': 'round'
        stroke: d.color
      ).appendTo(svg('g', transform: "translate(#{r},#{r})").appendTo(el))
      
      for i in [0..d.segments]
        g.append(svg('line',
          x1: 0
          y1: innerRadius
          x2: 0
          y2: innerRadius + d.length
          transform: "rotate(#{(360 / d.segments * i)}, 0, 0)"
          opacity: $.fn.activity.getOpacity(d, i)
        ))
      return $('<div>').append(el).width(2*r).height(2*r)
        
    # Check if Webkit CSS animations are available, as they work much better on the iPad
    # than setTimeout() based animations.
    
    if document.createElement('div').style.WebkitAnimationName != undefined

      animations = {}
    
      #
      # Animation strategy that uses dynamically created CSS animation rules.
      #
      animate = (el, steps, duration) ->
        if !animations[steps]
          name = 'spin' + steps
          rule = "@-webkit-keyframes #{name} {"
          for i in [0..steps]
            p1 = Math.round(100000 / steps * i) / 1000
            p2 = Math.round(100000 / steps * (i+1) - 1) / 1000
            value = "% { -webkit-transform:rotate(#{Math.round(360 / steps * i)}deg) }\n"
            rule += p1 + value + p2 + value 
          rule += '100% { -webkit-transform:rotate(100deg) }\n}'
          document.styleSheets[0].insertRule(rule)
          animations[steps] = name
        el.css('-webkit-animation', "#{animations[steps]} #{duration}s linear infinite")
    else
      # 
      # Animation strategy that transforms a SVG element using setInterval().
      # 
      animate = (el, steps, duration) ->
        rotation = 0
        g = el.find('g g').get(0)
        el.data('interval', setInterval(->
          g.setAttributeNS(null, 'transform', "rotate(#{(++rotation % steps * (360 / steps))})")
        ,  duration * 1000 / steps))
  else
    
    # =======================================================================================
    # VML Rendering
    # =======================================================================================
    
    s = $('<shape>').css('behavior', 'url(#default#VML)').appendTo('body')
    if s.get(0).adj
      # VML support detected. Insert CSS rules for group, shape and stroke.
      sheet = document.createStyleSheet()
      $.each(['group', 'shape', 'stroke'], ->
        sheet.addRule(this, "behavior:url(#default#VML)")
      )
      
      #
      # Rendering strategy that creates a VML tree. 
      #
      render = (target, d) ->
        innerRadius = d.width*2 + d.space
        r = (innerRadius + d.length + Math.ceil(d.width / 2) + 1)
        s = r*2
        o = -Math.ceil(s/2)
        
        el = $('<group>', {coordsize: s + ' ' + s, coordorigin: o + ' ' + o}).css({top: o, left: o, width: s, height: s})
        for i in [0..d.segments]
          el.append($('<shape>', {path: 'm ' + innerRadius + ',0  l ' + (innerRadius + d.length) + ',0'}).css({
            width: s
            height: s
            rotation: (360 / d.segments * i) + 'deg'
          }).append($('<stroke>', {color: d.color, weight: d.width + 'px', endcap: 'round', opacity: $.fn.activity.getOpacity(d, i)})))
        return $('<group>', {coordsize: s + ' ' + s}).css({width: s, height: s, overflow: 'hidden'}).append(el)
    
      #
      # Animation strategy that modifies the VML rotation property using setInterval().
      #
      animate = (el, steps, duration) ->
        rotation = 0
        g = el.get(0)
        el.data 'interval', setInterval ->
          rotation++
          g.style.rotation = rotation % steps * (360 / steps)
        , duration * 1000 / steps
    $(s).remove()
