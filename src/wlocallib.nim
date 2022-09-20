import wlocallib/core
import std/strutils
  
type 
  LocalizerConfig = object
    compress*: string
    validate*: bool
proc ValidateHtml(html: string): string = 
  var hlines = html.splitlines
  if not hlines[0].toUpperAscii.startswith("<!DOCTYPE"):
    hlines.insert("<!DOCTYPE html>", 0)
  return hlines.join("\n")
proc newConfig*(compress: string; val=true): LocalizerConfig =
  return LocalizerConfig(compress: compress, validate: val)
proc localizeWebsite*(url: string; config = newConfig("nil")): string =
  var wdata = getUrl(url)
  if config.val:
    wdata = ValidateHtml(wdata)
  if config.compress == "before":
    wdata = compress(wdata)
  elif config.compress == "after":
    return compress(wdata.localize(url)).doctype(wdata)
  else:
    return wdata.localize(url).doctype(wdata)
  
proc localizeFile*(filepath: string; config = newConfig("nil")): string = 
  var wdata = readFile(filepath)
  if config.val:
    wdata = ValidateHtml(wdata)
  if config.compress == "before":
    wdata = compress(wdata)
  elif config.compress == "after":
    return compress(wdata.localize("file://" & filepath)).doctype(wdata)
  else:
    return wdata.localize("file://" & filepath).doctype(wdata)
proc localizeString*(str: string; config = newConfig("nil")): string = 
  var wdata = str
  if config.val:
    wdata = ValidateHtml(wdata)
  if config.compress == "before":
    wdata = compress(wdata)
  elif config.compress == "after":
    return compress(wdata.localize("string")).doctype(wdata)
  else:
    return wdata.localize("string").doctype(wdata)
  
  