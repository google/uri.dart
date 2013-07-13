library uri_template.utils;

// From the PatternCharacter rule here:
// http://ecma-international.org/ecma-262/5.1/#sec-15.10
final _specialChars = new RegExp(r'[\\\^\$\.\|\+\[\]\(\)\{\}]');

String escapeRegex(String str) {
  var sb = new StringBuffer();
  var chars = str.split('');
  for (var i = 0; i < chars.length; i++) {
    var c = chars[i];
    if (_specialChars.hasMatch(c)) {
      sb.write('\\$c');
    } else {
      sb.write(c);
    }
  }
  return sb.toString();
}
