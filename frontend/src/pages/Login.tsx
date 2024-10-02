/*
  This file is part of Edgehog.

  Copyright 2021-2024 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import { useCallback, useEffect, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { useLocation, useNavigate } from "react-router-dom";
import Alert from "react-bootstrap/Alert";
import Form from "react-bootstrap/Form";
import _ from "lodash";

import AuthPage from "components/AuthPage";
import Button from "components/Button";
import Spinner from "components/Spinner";
import Stack from "components/Stack";
import { useAuth } from "contexts/Auth";

interface FormData {
  tenantSlug: string;
  authToken: string;
  keepMeLoggedIn: boolean;
}

const getInitialFormData = (searchParams: URLSearchParams): FormData => ({
  tenantSlug: searchParams.get("tenantSlug") || "",
  authToken: searchParams.get("authToken") || "",
  keepMeLoggedIn: false,
});

const LoginPage = () => {
  const location = useLocation();
  const urlSearchParams = new URLSearchParams(location.search);
  const initialFormData = getInitialFormData(urlSearchParams);
  const redirectTo = urlSearchParams.get("redirectTo") || "";
  const [formData, setFormData] = useState<FormData>(initialFormData);
  const [validated, setValidated] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const [isLoggingIn, setIsLogginIn] = useState(false);
  const auth = useAuth();
  const intl = useIntl();
  const navigate = useNavigate();

  const handleLogin = useCallback(
    (formData: FormData) => {
      setIsLogginIn(true);
      const authConfig = _.pick(formData, ["tenantSlug", "authToken"]);
      const persistConfig = formData.keepMeLoggedIn;
      auth.login(authConfig, persistConfig).then((success) => {
        if (success) {
          navigate(redirectTo, { replace: true });
        } else {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Login.loginErrorFeedback"
              defaultMessage="Could not login, please make sure the credentials are valid."
            />,
          );
          setIsLogginIn(false);
        }
      });
    },
    [auth, navigate, redirectTo],
  );

  const handleSubmit: React.FormEventHandler<HTMLFormElement> = useCallback(
    (event) => {
      event.preventDefault();
      event.stopPropagation();
      const form = event.currentTarget;
      if (form.checkValidity() === false) {
        return setValidated(true);
      }
      handleLogin(formData);
    },
    [formData, handleLogin],
  );

  const handleInputChange: React.ChangeEventHandler<HTMLInputElement> =
    useCallback((event) => {
      const target = event.target;
      const value = target.type === "checkbox" ? target.checked : target.value;
      const field = target.id;
      setFormData((data) => ({ ...data, [field]: value }));
    }, []);

  useEffect(() => {
    if (initialFormData.tenantSlug && initialFormData.authToken) {
      handleLogin(initialFormData);
    }
    // Run once on mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <AuthPage>
      <Alert
        show={!!errorFeedback}
        variant="danger"
        onClose={() => setErrorFeedback(null)}
        dismissible
      >
        {errorFeedback}
      </Alert>
      <Form noValidate validated={validated} onSubmit={handleSubmit}>
        <Stack gap={3}>
          <Form.Group controlId="tenantSlug">
            <Form.Control
              value={formData.tenantSlug}
              onChange={handleInputChange}
              required
              placeholder={intl.formatMessage({
                id: "pages.Login.tenantSlugPlaceholder",
                defaultMessage: "Tenant Slug",
              })}
              autoCapitalize="off"
              autoCorrect="off"
              spellCheck={false}
              pattern="^[a-z\d\-]+$"
            />
            <Form.Control.Feedback type="invalid">
              <FormattedMessage
                id="pages.Login.invalidTenantSlugFeedback"
                defaultMessage="Please provide a valid tenant slug."
              />
            </Form.Control.Feedback>
          </Form.Group>
          <Form.Group controlId="authToken">
            <Form.Control
              as="textarea"
              value={formData.authToken}
              onChange={handleInputChange}
              placeholder={intl.formatMessage({
                id: "pages.Login.authTokenPlaceholder",
                defaultMessage: "Auth Token",
              })}
              rows={8}
              autoCapitalize="off"
              autoCorrect="off"
              spellCheck={false}
            />
            <Form.Control.Feedback type="invalid">
              <FormattedMessage
                id="pages.Login.invalidAuthTokenFeedback"
                defaultMessage="Please provide a valid auth token."
              />
            </Form.Control.Feedback>
          </Form.Group>
          <Form.Group controlId="keepMeLoggedIn">
            <Form.Check
              checked={formData.keepMeLoggedIn}
              onChange={handleInputChange}
              type="checkbox"
              label={
                <FormattedMessage
                  id="pages.Login.keepMeLoggedInLabel"
                  defaultMessage="Keep me logged in"
                />
              }
            />
          </Form.Group>
          <Button
            variant="primary"
            type="submit"
            className="w-100 mt-2"
            disabled={isLoggingIn}
          >
            {isLoggingIn && <Spinner size="sm" className="me-2" />}
            <FormattedMessage
              id="pages.Login.loginButton"
              defaultMessage="Login"
            />
          </Button>
        </Stack>
      </Form>
    </AuthPage>
  );
};

export default LoginPage;
