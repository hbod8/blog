// async function displayDataOnImage(image) {
//   let data = await window.exifr.parse(image);
//   let exp = (data.ExposureTime > .35 || decimalToFraction(data.ExposureTime).display.length > 10) ? data.ExposureTime : decimalToFraction(data.ExposureTime).display;
//   let iso = data.ISO;
//   let fln = data.FocalLength;
//   let apt = data.FNumber;
//   let exv = data.ExposureCompensation
//   let dataString = `${fln}mm f${apt} ${exp}s iso${iso} ${(exv == 0) ? "" : exv + "ev"}`;
//   let dataElement = document.createElement("small");
//   dataElement.innerText = dataString;
//   image.after(dataElement);
// }

// async function displayExifData() {
//   let images = document.getElementsByClassName("exif");
//   for (image of images) {
//     displayDataOnImage(image);
//   }
// }

// function gcd(a, b) {
//   return (b == 1) ? gcd(b, a % b) : a;
// }

// var decimalToFraction = function (_decimal) {
//   if (_decimal == parseInt(_decimal)) {
//     return {
//       top: parseInt(_decimal),
//       bottom: 1,
//       display: parseInt(_decimal) + '/' + 1
//     };
//   }
//   else {
//     var top = _decimal.toString().includes(".") ? _decimal.toString().replace(/\d+[.]/, '') : 0;
//     var bottom = Math.pow(10, top.toString().replace('-', '').length);
//     if (_decimal >= 1) {
//       top = +top + (Math.floor(_decimal) * bottom);
//     }
//     else if (_decimal <= -1) {
//       top = +top + (Math.ceil(_decimal) * bottom);
//     }

//     var x = Math.abs(gcd(top, bottom));
//     return {
//       top: (top / x),
//       bottom: (bottom / x),
//       display: (top / x) + '/' + (bottom / x)
//     };
//   }
// };

async function resizeMasonryItem(item) {
  let childImage = item.querySelector('img');
  if (childImage.complete) { // ensure image has loaded
    item.style.gridRowEnd = "span " + Math.floor((childImage.getBoundingClientRect().height + 32) / 10);
    return true;
  } else {
    return false;
  }
}

async function setupMasonry() {
  let masonryItems = document.getElementsByClassName('masonry-item');
  for (item of masonryItems) {
    if (item.getAttribute("m") != "done") {
      if (!(await resizeMasonryItem(item))) {
        setTimeout(setupMasonry, 250);
        break;
      } else {
        item.setAttribute("m", "done"); // mark the item as resized so we can skip it
      }
    }
  }
}

async function setupMasonryResize() {
  let masonryItems = document.getElementsByClassName('masonry-item');
  for (item of masonryItems) {
    item.setAttribute("m", "resize"); // un-mark all the items so we can re-compute
  }
  setupMasonry();
}

setupMasonry();
displayExifData();

window.addEventListener("resize", setupMasonryResize);