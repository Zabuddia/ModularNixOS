async function includeHTML(callback) {
  const includeElements = document.querySelectorAll("[data-include]");
  const tasks = [];

  includeElements.forEach(el => {
    const file = el.getAttribute("data-include");
    if (!file) return;

    const task = fetch(file)
      .then(response => {
        if (!response.ok) {
          el.innerHTML = "";
          return;
        }
        return response.text();
      })
      .then(text => {
        if (text !== undefined) {
          el.innerHTML = text;
        }
      })
      .catch(() => {
        el.innerHTML = "";
      });

    tasks.push(task);
  });

  await Promise.all(tasks);

  if (typeof callback === "function") {
    callback();
  }
}