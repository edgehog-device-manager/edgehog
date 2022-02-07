/*
  This file is part of Edgehog.

  Copyright 2022 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import Card from "react-bootstrap/Card";
import Col from "react-bootstrap/Col";
import Row from "react-bootstrap/Row";

import assets from "assets";
import "./AuthPage.scss";

type AuthPageProps = {
  children: JSX.Element | JSX.Element[];
};

const AuthPage = ({ children }: AuthPageProps) => {
  return (
    <div className="min-vh-100 d-flex flex-column justify-content-center align-items-center bg-light">
      <Card className="auth-card border-0 shadow">
        <Row className="m-0">
          <Col
            xs={0}
            lg={4}
            className="d-none d-lg-flex flex-column justify-content-center align-items-center border-end p-5"
          >
            <Card.Img src={assets.images.brand} alt="Edgehog" />
          </Col>
          <Col
            xs={12}
            lg={8}
            className="d-flex flex-column justify-content-center p-4"
          >
            <Card.Body>
              <h1 className="d-lg-none text-center mb-4">Edgehog</h1>
              {children}
            </Card.Body>
          </Col>
        </Row>
      </Card>
    </div>
  );
};

export default AuthPage;
