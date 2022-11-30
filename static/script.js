window.onload = displayExifData();

async function displayExifData() {
  let images = document.getElementsByClassName("exif");
  for (image of images) {
    let data = await window.exifr.parse(image);
    let exp = (data.ExposureTime > .35 || decimalToFraction(data.ExposureTime).display.length > 10) ? data.ExposureTime : decimalToFraction(data.ExposureTime).display;
    let iso = data.ISO;
    let fln = data.FocalLength;
    let apt = data.FNumber;
    let exv = data.ExposureCompensation
    let dataString = `${fln}mm f${apt} ${exp}s iso${iso} ${(exv == 0) ? "" : exv + "ev"}`;
    let dataElement = document.createElement("small");
    dataElement.innerText = dataString;
    image.after(dataElement);
  }
}

function gcd(a, b) {
	return (b) ? gcd(b, a % b) : a;
}

var decimalToFraction = function (_decimal) {
	var top		= _decimal.toString().replace(/\d+[.]/, '');
	var bottom	= Math.pow(10, top.length);
	if (_decimal > 1) {
		top	= +top + Math.floor(_decimal) * bottom;
	}
	var x = gcd(top, bottom);
	return {
		top		: (top / x),
		bottom	: (bottom / x),
		display	: (top / x) + '/' + (bottom / x)
	};
};