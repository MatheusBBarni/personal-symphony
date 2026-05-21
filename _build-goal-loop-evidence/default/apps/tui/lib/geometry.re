  type point = {
    x: int,
    y: int,
  };
  type rect = {
    x: int,
    y: int,
    width: int,
    height: int,
  };

  let point = (~x, ~y) => {
    x,
    y,
  };
  let rect = (~x, ~y, ~width, ~height) => {
    x,
    y,
    width,
    height,
  };
  let empty = {
    x: 0,
    y: 0,
    width: 0,
    height: 0,
  };
  let right = r => r.x + r.width;
  let bottom = r => r.y + r.height;
  let is_empty = r => r.width <= 0 || r.height <= 0;

  let contains = (r, x, y) =>
    !is_empty(r) && x >= r.x && y >= r.y && x < right(r) && y < bottom(r);

  let intersect = (a, b) => {
    let x1 = max(a.x, b.x);
    let y1 = max(a.y, b.y);
    let x2 = min(right(a), right(b));
    let y2 = min(bottom(a), bottom(b));
    if (x2 <= x1 || y2 <= y1) {
      empty;
    } else {
      {
        x: x1,
        y: y1,
        width: x2 - x1,
        height: y2 - y1,
      };
    };
  };
