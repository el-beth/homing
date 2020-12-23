s/( the | a )/.+/gi
s/^(the|a) /.+/gi
s/[AEIOU]/\.\+/gi
s/[^A-Z0-9]/\.\+/gi
s/^/\.\+/g
s/$/\.\*/g
s/(\.\+)+/\.\+/g