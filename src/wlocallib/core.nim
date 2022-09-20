import std/xmltree
from std/htmlparser import parseHtml
import nimquery, httpclient
import std/strtabs, std/strutils, std/uri, std/strtabs, std/typeinfo, std/mimetypes, std/strformat

proc getUrl*(url: string): string =
  let host = parseUri(url)
  var client = newHttpClient()
  client.headers = newHttpHeaders({"Referer": $host})
 
  let content = client.getContent(url)
  return content
proc processStyle(node: XmlNode, name: string): XmlNode =
  var url = node.attr("href")
  if url.startsWith("/"):
    url = name & url
  elif url.startswith("http://"):
    echo "Unsecured"
  elif not url.startswith("https://"):
    url = name & url
  let onode = newElement("style")
  onode.add newVerbatimText("\n" & getUrl(url) & "\n")
  var onode_attrs = @{"data-text-localize": "localized"}
  for name, value in node.attrs.pairs:
    if name == "class" or name == "id":
      onode_attrs.add((name, value))
    else:
      onode_attrs.add(("data-" & name, value))
  onode.attrs = onode_attrs.toXmlAttributes
  return onode
proc index(node: XmlNode, parent: XmlNode): int = 
  var i = 0
  for item in parent.items:
    if item == node:
       return i
    i += 1

proc processImage(node: XmlNode, name: string): XmlNode = 
  var url = node.attr("src")
  if url.startsWith("/"):
    url = name & url
  elif url.startswith("http://"):
    echo "Unsecured"
  elif not url.startswith("https://"):
    url = name & url  
  var node_attrs = @{"data-text-localize": "localized"}
  for name, value in node.attrs.pairs:
    if name == "class" or name == "id" or name == "height" or name == "width":
      node_attrs.add((name, value))
    else:
      node_attrs.add(("data-" & name, value))
  let
    host = parseUri(url)
    client = newHttpClient(headers=newHttpHeaders({"Referer": $host}))
    rq = client.get(url)
    suffix = newMimetypes().getExt(rq.headers["Content-Type"])
  node_attrs.add(("src", getDataUri(rq.body, &"image/{suffix}")))
  node.attrs = node_attrs.toXmlAttributes
  return node

proc processScript(node: XmlNode, name: string): XmlNode = 
  var url = node.attr("src")
  if url.startsWith("/"):
    url = name & url
  elif url.startswith("http://"):
    echo "Unsecured"
  elif not url.startswith("https://"):
    url = name & url  
  var node_attrs = @{"data-text-localize": "localized"}
  for name, value in node.attrs.pairs:
    if name == "class" or name == "id":
      node_attrs.add((name, value))
    else:
      node_attrs.add(("data-" & name, value))
  node.attrs = node_attrs.toXmlAttributes
  node.add newVerbatimText( getUrl(url) )
  return node
proc localize*(html: string, name: string): string =
  let xml = parseHtml(html)
  if xml.child("html") == nil:
     discard newException(OSError, "The html was missing tag <html>.")
  let styles = xml.querySelectorAll("link")
  var stylecont = newElement("div")
  #stylecont.add newText("\n")
  stylecont.attrs = {"data-l-wrapper": "style-container"}.toXmlAttributes
  for style in styles:
    if style.attr("rel") == "stylesheet":
      stylecont.add processStyle(style, name)
      let head = xml.child("html").child("head")
      head.delete(style.index(head))
  #stylecont.add newText("\n")
  xml.child("html").child("body").insert(stylecont, 0)
  let scripts = xml.querySelectorAll("script")
  for script in scripts:
    if script.attr("src") != "":
      #echo script.attr("src") != ""
      let scriptOut = processScript(script, name)
      #let parent = xml.findparent(script)
      #echo script.attr("src") != ""
      #parent.replaceChild(script, scriptOut)
  let imgs = xml.querySelectorAll("img")
  for img in imgs:
    if not img.attr("src").startswith("data:"):
      if img.attr("src") != "":
        
        let scriptOutImg = processImage(img, name)
  
  
  return $xml
proc compress*(html: string): string =
  let client = newHttpClient()
  let mhtml = "code=" & encodeUrl(html, false)
  client.headers = newHttpHeaders({"Content-Type": "application/x-www-form-urlencoded", "Content-Encoding": "gzip"})
  let output = client.request("https://htmlcompressor.com/compress", httpMethod = HttpPost, body=mhtml)
  let outt = output.body
  if output.status == "400 Bad Request":
    raise newException(OSError, "The html was either to large or invalid.")
  return outt
proc doctype*(html: string, origin: string): string =
  let doctype = origin.splitlines(true)[0]
  let doclines = html.splitlines()
  let output = doclines[1 .. ^2].join("\n")
  return doctype & output