import { Navigate, useRoutes } from "react-router-dom";

import { Route } from "Navigation";
import Device from "pages/Device";

const Sidebar = () => null; // TODO: Implement
const Topbar = () => null; // TODO: Implement

type RouterRule = {
  path: string;
  element: JSX.Element;
};

const routes: RouterRule[] = [
  { path: Route.devicesEdit, element: <Device /> },
  { path: "*", element: <Navigate to={Route.devicesEdit} /> },
];

function App() {
  const isAuthenticated = true; // TODO: Implement authentication
  const RouterElement = useRoutes(routes);

  return (
    <div data-testid="app" className="d-flex vh-100 flex-column">
      {isAuthenticated && (
        <header className="flex-grow-0">
          <Topbar />
        </header>
      )}
      <main className="vh-100 flex-grow-1 d-flex  overflow-hidden">
        {isAuthenticated && (
          <aside className="flex-grow-0 flex-shrink-0 overflow-auto">
            <Sidebar />
          </aside>
        )}
        <section className="flex-grow-1 overflow-auto">{RouterElement}</section>
      </main>
    </div>
  );
}

export default App;
