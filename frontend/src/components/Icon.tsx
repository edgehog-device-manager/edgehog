import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faCircle,
  faSearch,
  faArrowDown,
  faArrowUp,
} from "@fortawesome/free-solid-svg-icons";

const icons = {
  circle: faCircle,
  search: faSearch,
  arrowDown: faArrowDown,
  arrowUp: faArrowUp,
} as const;

type FontAwesomeIconProps = React.ComponentProps<typeof FontAwesomeIcon>;

type Props = Omit<FontAwesomeIconProps, "icon"> & {
  icon: keyof typeof icons;
};

const Icon = ({ icon, ...restProps }: Props) => {
  return <FontAwesomeIcon {...restProps} icon={icons[icon]} />;
};

export default Icon;
