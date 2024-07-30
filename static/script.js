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

window.addEventListener("resize", setupMasonryResize);