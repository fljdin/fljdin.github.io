---
title: Lectures personnelles
---

<div class="readings">
{{ range $.Site.Data.readings }}
  <div class="done">
    {{- if isset . "isbn" -}}
      <img src="http://images.amazon.com/images/P/{{ reading.isbn }}" alt="{{ reading.title }} - {{ reading.author }}" />
    {{- else -}}  
      &nbsp;&nbsp;<a href="{{ .url }}">{{ .text }}</a>
    {{- end -}}
  </div>
{{ end }}
</div>