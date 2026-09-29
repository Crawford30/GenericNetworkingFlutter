enum ContentType {
  json('application/json'),
  formData('multipart/form-data'),
  urlEncoded('application/x-www-form-urlencoded'),
  text('text/plain'),
  html('text/html');

  const ContentType(this.value);

  final String value;
}
