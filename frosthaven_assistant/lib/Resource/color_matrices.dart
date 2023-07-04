//for use with ColorFiltered widget

List<double> grayScale = [
//R  G   B    A  Const
  0.2126, 0.59, 0.11, 0, 0, //
  0.2126, 0.59, 0.11, 0, 0, //
  0.2126, 0.59, 0.11, 0, 0, //
  0, 0, 0, 1, 0, //
];

List<double> grayScale2 = [
//R  G   B    A  Const
  0.33, 0.7152, 0.0722, 0, 0, //
  0.33, 0.7152, 0.0722, 0, 0, //
  0.33, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

List<double> identity = [
//R  G   B    A  Const
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

List<double> inverse = [
//R  G   B    A  Const
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255, //
  0, 0, -1, 0, 255, //
  0, 0, 0, 1, 0, //
];

List<double> sepia = [
//R  G   B    A  Const
  0.393, 0.769, 0.189, 0, 0, //
  0.349, 0.686, 0.168, 0, 0, //
  0.272, 0.534, 0.131, 0, 0, //
  0, 0, 0, 1, 0, //
];

Map<String, List<double>> colorFilters = {
  'Identity': [
    //R  G   B    A  Const
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
  'Grey Scale': [
    //R  G   B    A  Const
    0.33, 0.59, 0.11, 0, 0, //
    0.33, 0.59, 0.11, 0, 0, //
    0.33, 0.59, 0.11, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
  'Inverse': [
    //R  G   B    A  Const
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0, //
  ],
  'Sepia': [
    //R  G   B    A  Const
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0, //
    0.272, 0.534, 0.131, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
};
